import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import './SpeechBubbles.css';

const PHRASES = [
    "Hey, let's grab a drink!",
    "We're meeting at the cafe!",
    "Are you guys here?",
    "Anyone up for yoga?",
    "Let's party at mine!"
];

const SpeechBubbles = () => {
    const [activeBubble, setActiveBubble] = useState(null);

    useEffect(() => {
        const showNextBubble = () => {
            // Pick a random phrase
            const randomPhrase = PHRASES[Math.floor(Math.random() * PHRASES.length)];

            // Random position (safe zones)
            // avoiding top 10% (camera) and bottom 40% (event card)
            const randomY = 15 + Math.random() * 40; // 15% to 55% from top

            // Randomize X slightly (left or right side) or center variance
            // 10% to 50% (left) or 50% to 90% (right)?
            // Let's keep it somewhat centered but varying: 10% to 60% left
            const randomLeft = 10 + Math.random() * 50;

            // Deciding alignment? 
            // If on left half, tail on left? Simplified: Just centered bubbles at random offset.

            setActiveBubble({
                text: randomPhrase,
                top: `${randomY}%`,
                left: `${randomLeft}%`
            });

            // Hide after 2.5s (so there's a gap)
            setTimeout(() => {
                setActiveBubble(null);
            }, 2500);
        };

        // Initial bubble
        showNextBubble();

        // Loop every 3 seconds (5 phrases * 3s = 15s sequence roughly)
        const interval = setInterval(showNextBubble, 3000);

        return () => clearInterval(interval);
    }, []);

    return (
        <div className="speech-bubbles-container">
            <AnimatePresence>
                {activeBubble && (
                    <motion.div
                        className="speech-bubble"
                        initial={{ opacity: 0, scale: 0.8, y: 10 }}
                        animate={{ opacity: 1, scale: 1, y: 0 }}
                        exit={{ opacity: 0, scale: 0.8, y: -10 }}
                        style={{ top: activeBubble.top, left: activeBubble.left }}
                    >
                        {activeBubble.text}
                        <div className="bubble-tail"></div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default SpeechBubbles;
