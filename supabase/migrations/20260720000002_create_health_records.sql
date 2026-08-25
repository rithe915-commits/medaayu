-- Create health records table
CREATE TABLE IF NOT EXISTS public.health_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  doctor_name TEXT,
  record_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes TEXT,
  file_url TEXT,
  file_type TEXT DEFAULT 'image',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.health_records ENABLE ROW LEVEL SECURITY;

-- Select policy
CREATE POLICY select_health_records ON public.health_records
  FOR SELECT TO authenticated
  USING (profile_id IN (
    SELECT p.id FROM public.profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM public.profiles WHERE id = auth.uid())
  ));

-- Insert policy
CREATE POLICY insert_health_records ON public.health_records
  FOR INSERT TO authenticated
  WITH CHECK (profile_id IN (
    SELECT p.id FROM public.profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM public.profiles WHERE id = auth.uid())
  ));

-- Update policy
CREATE POLICY update_health_records ON public.health_records
  FOR UPDATE TO authenticated
  USING (profile_id IN (
    SELECT p.id FROM public.profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM public.profiles WHERE id = auth.uid())
  ))
  WITH CHECK (profile_id IN (
    SELECT p.id FROM public.profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM public.profiles WHERE id = auth.uid())
  ));

-- Delete policy
CREATE POLICY delete_health_records ON public.health_records
  FOR DELETE TO authenticated
  USING (profile_id IN (
    SELECT p.id FROM public.profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM public.profiles WHERE id = auth.uid())
  ));
