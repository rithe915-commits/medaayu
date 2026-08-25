-- Fix insert policy for profiles to allow caregivers to insert parent profiles
DROP POLICY IF EXISTS insert_profiles ON public.profiles;

CREATE POLICY insert_profiles ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid() OR owner_id = auth.uid());
