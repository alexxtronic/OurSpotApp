// Supabase Edge Function: Send Chat Notification
// Triggered via database webhook on new chat message insert

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// APNs configuration from secrets
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") || "com.ourspot.app";
const APNS_ENVIRONMENT = Deno.env.get("APNS_ENVIRONMENT") || "production"; // "development" for sandbox

// Supabase setup
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ChatMessage {
    id: string;
    plan_id: string;
    user_id: string;
    content: string;
    created_at: string;
}

interface NotificationRecipient {
    user_id: string;
    apns_token: string;
}

interface SenderInfo {
    name: string;
}

serve(async (req) => {
    try {
        // Parse webhook payload
        const payload = await req.json();
        const message: ChatMessage = payload.record;

        if (!message) {
            return new Response(JSON.stringify({ error: "No message in payload" }), {
                status: 400,
                headers: { "Content-Type": "application/json" },
            });
        }

        console.log(`Processing notification for message ${message.id} in plan ${message.plan_id}`);

        // Create Supabase client with service role
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

        // Get sender info
        const { data: senderData } = await supabase
            .from("profiles")
            .select("name")
            .eq("id", message.user_id)
            .single();

        const senderName = (senderData as SenderInfo)?.name || "Someone";

        // Get notification recipients
        const { data: recipients, error: recipientsError } = await supabase.rpc(
            "get_notification_recipients",
            {
                p_plan_id: message.plan_id,
                p_sender_id: message.user_id,
            }
        );

        if (recipientsError) {
            console.error("Error fetching recipients:", recipientsError);
            return new Response(JSON.stringify({ error: "Failed to fetch recipients" }), {
                status: 500,
                headers: { "Content-Type": "application/json" },
            });
        }

        if (!recipients || recipients.length === 0) {
            console.log("No recipients to notify");
            return new Response(JSON.stringify({ message: "No recipients" }), {
                status: 200,
                headers: { "Content-Type": "application/json" },
            });
        }

        console.log(`Sending notifications to ${recipients.length} recipients`);

        // Generate APNs JWT
        const jwt = await generateAPNsJWT();

        // Send notifications in parallel
        const results = await Promise.allSettled(
            (recipients as NotificationRecipient[]).map((recipient) =>
                sendAPNsNotification(jwt, recipient.apns_token, {
                    title: senderName,
                    body: truncateMessage(message.content, 100),
                    planId: message.plan_id,
                    messageId: message.id,
                })
            )
        );

        // Count successes and failures
        const succeeded = results.filter((r) => r.status === "fulfilled").length;
        const failed = results.filter((r) => r.status === "rejected").length;

        // Clean up invalid tokens
        const invalidTokens: string[] = [];
        results.forEach((result, index) => {
            if (result.status === "rejected" && result.reason?.status === 410) {
                invalidTokens.push((recipients as NotificationRecipient[])[index].apns_token);
            }
        });

        if (invalidTokens.length > 0) {
            console.log(`Cleaning up ${invalidTokens.length} invalid tokens`);
            await supabase
                .from("device_tokens")
                .delete()
                .in("apns_token", invalidTokens);
        }

        return new Response(
            JSON.stringify({
                success: true,
                sent: succeeded,
                failed: failed,
                invalidTokensCleaned: invalidTokens.length,
            }),
            {
                status: 200,
                headers: { "Content-Type": "application/json" },
            }
        );
    } catch (error) {
        console.error("Edge function error:", error);
        return new Response(JSON.stringify({ error: String(error) }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
        });
    }
});

// MARK: - APNs JWT Generation

async function generateAPNsJWT(): Promise<string> {
    const header = {
        alg: "ES256",
        kid: APNS_KEY_ID,
    };

    const now = Math.floor(Date.now() / 1000);
    const claims = {
        iss: APNS_TEAM_ID,
        iat: now,
    };

    const encodedHeader = base64UrlEncode(JSON.stringify(header));
    const encodedClaims = base64UrlEncode(JSON.stringify(claims));
    const signingInput = `${encodedHeader}.${encodedClaims}`;

    // Import the private key
    const privateKey = await crypto.subtle.importKey(
        "pkcs8",
        pemToArrayBuffer(APNS_PRIVATE_KEY),
        { name: "ECDSA", namedCurve: "P-256" },
        false,
        ["sign"]
    );

    // Sign
    const signature = await crypto.subtle.sign(
        { name: "ECDSA", hash: "SHA-256" },
        privateKey,
        new TextEncoder().encode(signingInput)
    );

    const encodedSignature = base64UrlEncode(new Uint8Array(signature));
    return `${signingInput}.${encodedSignature}`;
}

// MARK: - Send APNs Notification

interface NotificationPayload {
    title: string;
    body: string;
    planId: string;
    messageId: string;
}

async function sendAPNsNotification(
    jwt: string,
    deviceToken: string,
    payload: NotificationPayload
): Promise<void> {
    const host =
        APNS_ENVIRONMENT === "development"
            ? "api.sandbox.push.apple.com"
            : "api.push.apple.com";

    const apnsPayload = {
        aps: {
            alert: {
                title: payload.title,
                body: payload.body,
            },
            sound: "default",
            badge: 1,
            "mutable-content": 1,
        },
        plan_id: payload.planId,
        message_id: payload.messageId,
    };

    const response = await fetch(`https://${host}/3/device/${deviceToken}`, {
        method: "POST",
        headers: {
            Authorization: `bearer ${jwt}`,
            "apns-topic": APNS_BUNDLE_ID,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "apns-collapse-id": `chat-${payload.planId}`, // Collapse multiple messages per chat
        },
        body: JSON.stringify(apnsPayload),
    });

    if (!response.ok) {
        const error = await response.text();
        console.error(`APNs error for ${deviceToken}: ${response.status} - ${error}`);
        throw { status: response.status, message: error };
    }
}

// MARK: - Helpers

function truncateMessage(message: string, maxLength: number): string {
    if (message.length <= maxLength) return message;
    return message.substring(0, maxLength - 3) + "...";
}

function base64UrlEncode(input: string | Uint8Array): string {
    let bytes: Uint8Array;
    if (typeof input === "string") {
        bytes = new TextEncoder().encode(input);
    } else {
        bytes = input;
    }

    let base64 = btoa(String.fromCharCode(...bytes));
    return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
    // Remove PEM headers and newlines
    const base64 = pem
        .replace(/-----BEGIN PRIVATE KEY-----/, "")
        .replace(/-----END PRIVATE KEY-----/, "")
        .replace(/\n/g, "");

    const binaryString = atob(base64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
}
