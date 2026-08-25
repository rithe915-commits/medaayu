-- Allow profiles to exist without a matching auth.users row
-- This lets caregivers create parent profiles that auto-link when the parent logs in

-- 1. Drop the FK constraint that requires profiles.id to exist in auth.users
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- 2. Add a SECURITY DEFINER function to create parent profiles server-side
--    (called by the app via supabase.rpc('create_parent_profile', {...}))
CREATE OR REPLACE FUNCTION public.create_parent_profile(
  p_full_name    TEXT,
  p_phone        TEXT,
  p_age          INT      DEFAULT NULL,
  p_gender       TEXT     DEFAULT NULL,
  p_blood_group  TEXT     DEFAULT NULL,
  p_plan_tier    TEXT     DEFAULT 'basic',
  p_language     TEXT     DEFAULT 'english',
  p_sos_action   TEXT     DEFAULT 'notify',
  p_sos_contact  TEXT     DEFAULT NULL,
  p_sos_contact2 TEXT     DEFAULT NULL,
  p_email        TEXT     DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id   UUID := auth.uid();
  v_profile_id UUID;
  v_clean_phone TEXT;
BEGIN
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Clean phone to last 10 digits
  v_clean_phone := right(regexp_replace(p_phone, '[^0-9]', '', 'g'), 10);

  -- Check if a profile already exists for this phone number
  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE phone = v_clean_phone
  LIMIT 1;

  IF v_profile_id IS NOT NULL THEN
    -- Update existing profile to link to this caregiver
    UPDATE public.profiles SET
      owner_id        = v_owner_id,
      full_name       = p_full_name,
      age             = COALESCE(p_age, age),
      gender          = COALESCE(p_gender, gender),
      blood_group     = COALESCE(p_blood_group, blood_group),
      plan_tier       = p_plan_tier,
      language        = p_language,
      sos_action      = p_sos_action,
      sos_contact_phone   = COALESCE(p_sos_contact, sos_contact_phone),
      sos_contact_phone_2 = COALESCE(p_sos_contact2, sos_contact_phone_2),
      email           = COALESCE(p_email, email),
      role            = 'parent'
    WHERE id = v_profile_id;
  ELSE
    -- Generate a new UUID for this parent profile
    v_profile_id := gen_random_uuid();

    INSERT INTO public.profiles (
      id, owner_id, role, full_name, phone, age, gender, blood_group,
      plan_tier, language, sos_action, sos_contact_phone, sos_contact_phone_2, email
    ) VALUES (
      v_profile_id, v_owner_id, 'parent', p_full_name, v_clean_phone,
      p_age, p_gender, p_blood_group,
      p_plan_tier, p_language, p_sos_action, p_sos_contact, p_sos_contact2, p_email
    );
  END IF;

  RETURN v_profile_id;
END;
$$;

-- 3. Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.create_parent_profile TO authenticated;
