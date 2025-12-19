-- OurSpot Database Schema (Simplified)
-- Run this in Supabase SQL Editor

-- Enable UUID extension (usually already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    age INTEGER CHECK (age >= 13 AND age <= 120),
    bio TEXT DEFAULT '',
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

-- ============================================
-- PLANS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    host_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    emoji TEXT DEFAULT '📍',
    activity_type TEXT DEFAULT 'social',
    address_text TEXT DEFAULT '',
    is_private BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_plans_host ON plans(host_user_id);
CREATE INDEX IF NOT EXISTS idx_plans_starts_at ON plans(starts_at);

-- ============================================
-- RSVPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS rsvps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'going' CHECK (status IN ('going', 'maybe', 'not_going', 'pending')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(plan_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_rsvps_plan ON rsvps(plan_id);
CREATE INDEX IF NOT EXISTS idx_rsvps_user ON rsvps(user_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE rsvps ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read all, update own
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Plans: anyone can read, owner can modify
CREATE POLICY "plans_select" ON plans FOR SELECT USING (true);
CREATE POLICY "plans_insert" ON plans FOR INSERT WITH CHECK (auth.uid() = host_user_id);
CREATE POLICY "plans_update" ON plans FOR UPDATE USING (auth.uid() = host_user_id);
CREATE POLICY "plans_delete" ON plans FOR DELETE USING (auth.uid() = host_user_id);

-- RSVPs: anyone can read, users can manage their own
CREATE POLICY "rsvps_select" ON rsvps FOR SELECT USING (true);
CREATE POLICY "rsvps_insert" ON rsvps FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "rsvps_update" ON rsvps FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "rsvps_delete" ON rsvps FOR DELETE USING (auth.uid() = user_id);
