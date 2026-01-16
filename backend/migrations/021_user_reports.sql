-- Create user_reports table
CREATE TABLE IF NOT EXISTS public.user_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES auth.users(id) NOT NULL,
    reported_id UUID REFERENCES auth.users(id) NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Policy: Authenticated users can insert reports
CREATE POLICY "Users can create reports" 
ON public.user_reports 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = reporter_id);

-- Policy: Users can view their own reports (optional, but good for history)
CREATE POLICY "Users can view their own reports" 
ON public.user_reports 
FOR SELECT 
TO authenticated 
USING (auth.uid() = reporter_id);

-- Add indexes
CREATE INDEX idx_user_reports_reporter ON public.user_reports(reporter_id);
CREATE INDEX idx_user_reports_reported ON public.user_reports(reported_id);
CREATE INDEX idx_user_reports_status ON public.user_reports(status);
