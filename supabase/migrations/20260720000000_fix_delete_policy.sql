DROP POLICY IF EXISTS delete_profiles ON public.profiles;

CREATE POLICY delete_profiles ON public.profiles
  FOR DELETE TO authenticated
  USING (id = auth.uid() OR owner_id = auth.uid());
