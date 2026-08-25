-- 1. Drop and recreate select policy to allow phone-based lookups
DROP POLICY IF EXISTS select_profiles ON public.profiles;
CREATE POLICY select_profiles ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid() 
    OR owner_id = auth.uid() 
    OR id = public.get_user_owner_id(auth.uid()) 
    OR phone = right(auth.jwt() ->> 'phone', 10)
  );

-- 2. Drop and recreate update policy to allow phone-based profile ID assimilation
DROP POLICY IF EXISTS update_profiles ON public.profiles;
CREATE POLICY update_profiles ON public.profiles
  FOR UPDATE TO authenticated
  USING (
    id = auth.uid() 
    OR owner_id = auth.uid() 
    OR phone = right(auth.jwt() ->> 'phone', 10)
  )
  WITH CHECK (
    id = auth.uid() 
    OR owner_id = auth.uid() 
    OR phone = right(auth.jwt() ->> 'phone', 10)
  );
