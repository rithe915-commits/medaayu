-- Create intake logs table
CREATE TABLE IF NOT EXISTS public.intake_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id UUID NOT NULL REFERENCES public.medicines(id) ON DELETE CASCADE,
  taken_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS for intake_logs
ALTER TABLE public.intake_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_intake_logs ON public.intake_logs
  FOR SELECT TO authenticated
  USING (medicine_id IN (SELECT id FROM public.medicines));

CREATE POLICY insert_intake_logs ON public.intake_logs
  FOR INSERT TO authenticated
  WITH CHECK (medicine_id IN (SELECT id FROM public.medicines));

-- Add color and photo_url columns to medicines
ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS color TEXT;
ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS photo_url TEXT;
