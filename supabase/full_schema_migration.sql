-- ========================================================
-- MEDAAYU COMPLETE DATABASE SETUP SCRIPT FOR NEW SUPABASE
-- Run this in: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ========================================================

-- 1. Create Enums
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('self', 'parent');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'plan_tier') THEN
    CREATE TYPE plan_tier AS ENUM ('basic', 'standard', 'premium');
  END IF;
END $$;

-- 2. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  role user_role NOT NULL DEFAULT 'self',
  full_name TEXT NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  age INT,
  gender TEXT,
  blood_group TEXT,
  email TEXT,
  sos_contact_phone TEXT,
  sos_contact_phone_2 TEXT,
  sos_action TEXT NOT NULL DEFAULT 'notify',
  plan_tier plan_tier NOT NULL DEFAULT 'basic',
  plan_expires_at TIMESTAMPTZ,
  language TEXT NOT NULL DEFAULT 'english',
  care_tips TEXT,
  care_tips_updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Medicines Table
CREATE TABLE IF NOT EXISTS public.medicines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  form TEXT NOT NULL DEFAULT 'Pill',
  frequency TEXT NOT NULL DEFAULT 'Daily',
  dose_time TIME NOT NULL,
  pills_left INT DEFAULT 30,
  food_instruction TEXT NOT NULL DEFAULT 'before_food',
  color TEXT,
  photo_url TEXT,
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Intake Logs Table
CREATE TABLE IF NOT EXISTS public.intake_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id UUID NOT NULL REFERENCES public.medicines(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'taken',
  taken_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Health Records Table
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

-- 6. Reminder Logs Table
CREATE TABLE IF NOT EXISTS public.reminder_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id UUID NOT NULL REFERENCES public.medicines(id) ON DELETE CASCADE,
  channel TEXT NOT NULL DEFAULT 'tts_call',
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'success'
);

-- 7. SOS Events Table
CREATE TABLE IF NOT EXISTS public.sos_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  resolved BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. OTP Verifications Table
CREATE TABLE IF NOT EXISTS public.otp_verifications (
  phone TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Auto update timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS update_medicines_updated_at ON public.medicines;
CREATE TRIGGER update_medicines_updated_at
  BEFORE UPDATE ON public.medicines
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- 10. Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intake_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminder_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

-- 11. Permissive RLS Policies for MedAayu Clients & Functions
DROP POLICY IF EXISTS "profiles_all" ON public.profiles;
CREATE POLICY "profiles_all" ON public.profiles FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "medicines_all" ON public.medicines;
CREATE POLICY "medicines_all" ON public.medicines FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "intake_logs_all" ON public.intake_logs;
CREATE POLICY "intake_logs_all" ON public.intake_logs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "health_records_all" ON public.health_records;
CREATE POLICY "health_records_all" ON public.health_records FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "reminder_logs_all" ON public.reminder_logs;
CREATE POLICY "reminder_logs_all" ON public.reminder_logs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "sos_events_all" ON public.sos_events;
CREATE POLICY "sos_events_all" ON public.sos_events FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "otp_verifications_all" ON public.otp_verifications;
CREATE POLICY "otp_verifications_all" ON public.otp_verifications FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- 12. Storage Bucket for Medical Photos & PDFs
INSERT INTO storage.buckets (id, name, public)
VALUES ('medaayu_photos', 'medaayu_photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Access medaayu_photos" ON storage.objects;
CREATE POLICY "Public Access medaayu_photos" ON storage.objects FOR SELECT USING (bucket_id = 'medaayu_photos');

DROP POLICY IF EXISTS "Allow All Insert medaayu_photos" ON storage.objects;
CREATE POLICY "Allow All Insert medaayu_photos" ON storage.objects FOR INSERT TO anon, authenticated WITH CHECK (bucket_id = 'medaayu_photos');

DROP POLICY IF EXISTS "Allow All Update medaayu_photos" ON storage.objects;
CREATE POLICY "Allow All Update medaayu_photos" ON storage.objects FOR UPDATE TO anon, authenticated USING (bucket_id = 'medaayu_photos');

DROP POLICY IF EXISTS "Allow All Delete medaayu_photos" ON storage.objects;
CREATE POLICY "Allow All Delete medaayu_photos" ON storage.objects FOR DELETE TO anon, authenticated USING (bucket_id = 'medaayu_photos');

-- 13. Create Parent Profile Helper RPC Function
CREATE OR REPLACE FUNCTION public.create_parent_profile(
  p_full_name    TEXT,
  p_phone        TEXT,
  p_age          INT      DEFAULT NULL,
  p_gender       TEXT     DEFAULT NULL,
  p_blood_group  TEXT     DEFAULT NULL,
  p_plan_tier    public.plan_tier DEFAULT 'basic',
  p_language     TEXT     DEFAULT 'english',
  p_sos_action   TEXT     DEFAULT 'notify',
  p_sos_contact  TEXT     DEFAULT NULL,
  p_sos_contact2 TEXT     DEFAULT NULL,
  p_email        TEXT     DEFAULT NULL,
  p_owner_id     UUID     DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id   UUID := COALESCE(p_owner_id, auth.uid());
  v_profile_id UUID;
  v_clean_phone TEXT;
BEGIN
  v_clean_phone := right(regexp_replace(p_phone, '[^0-9]', '', 'g'), 10);

  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE phone = v_clean_phone
  LIMIT 1;

  IF v_profile_id IS NOT NULL THEN
    UPDATE public.profiles SET
      owner_id            = COALESCE(v_owner_id, owner_id),
      full_name           = p_full_name,
      age                 = COALESCE(p_age, age),
      gender              = COALESCE(p_gender, gender),
      blood_group         = COALESCE(p_blood_group, blood_group),
      plan_tier           = p_plan_tier,
      language            = p_language,
      sos_action          = p_sos_action,
      sos_contact_phone   = COALESCE(p_sos_contact, sos_contact_phone),
      sos_contact_phone_2 = COALESCE(p_sos_contact2, sos_contact_phone_2),
      email               = COALESCE(p_email, email),
      role                = 'parent'
    WHERE id = v_profile_id;
  ELSE
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

GRANT EXECUTE ON FUNCTION public.create_parent_profile TO anon, authenticated;
