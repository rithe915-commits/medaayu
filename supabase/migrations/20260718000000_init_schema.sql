-- Create custom types / enums
CREATE TYPE user_role AS ENUM ('self', 'parent');
CREATE TYPE plan_tier AS ENUM ('basic', 'standard', 'premium');

-- Profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL, -- for linked parent profiles
  role user_role NOT NULL DEFAULT 'self',
  full_name TEXT NOT NULL,
  age INT,
  gender TEXT,
  blood_group TEXT,
  phone TEXT UNIQUE NOT NULL,
  sos_contact_phone TEXT,
  plan_tier plan_tier NOT NULL DEFAULT 'basic',
  language TEXT NOT NULL DEFAULT 'english',
  sos_action TEXT NOT NULL DEFAULT 'notify', -- 'notify' (SMS only) or 'notify_and_ambulance'
  care_tips TEXT,
  care_tips_updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Medicines table
CREATE TABLE medicines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  form TEXT NOT NULL, -- e.g. Pill, Capsule, Liquid, Injection
  frequency TEXT NOT NULL, -- e.g. Daily, Weekly
  dose_time TIME NOT NULL, -- e.g. '08:00:00'
  pills_left INT,
  food_instruction TEXT NOT NULL DEFAULT 'before_food', -- 'before_food', 'after_food', 'with_food', 'none'
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- SOS events table
CREATE TABLE sos_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  resolved BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Reminder log table
CREATE TABLE reminder_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id UUID NOT NULL REFERENCES medicines(id) ON DELETE CASCADE,
  channel TEXT NOT NULL, -- 'local_alarm', 'whatsapp', 'tts_call'
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL -- 'success', 'failed'
);

-- Temp table for storing custom OTP verifications
CREATE TABLE otp_verifications (
  phone TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger to auto-update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER update_medicines_updated_at BEFORE UPDATE ON medicines
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminder_logs ENABLE ROW LEVEL SECURITY;

-- Enable RLS for otp_verifications - restricted to service role only
ALTER TABLE otp_verifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Profiles
CREATE POLICY select_profiles ON profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR owner_id = auth.uid() OR id IN (SELECT owner_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY insert_profiles ON profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY update_profiles ON profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid() OR owner_id = auth.uid())
  WITH CHECK (id = auth.uid() OR owner_id = auth.uid());

CREATE POLICY delete_profiles ON profiles
  FOR DELETE TO authenticated
  USING (id = auth.uid());

-- RLS Policies for Medicines
CREATE POLICY select_medicines ON medicines
  FOR SELECT TO authenticated
  USING (profile_id IN (
    SELECT p.id FROM profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));

CREATE POLICY insert_medicines ON medicines
  FOR INSERT TO authenticated
  WITH CHECK (profile_id IN (
    SELECT p.id FROM profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));

CREATE POLICY update_medicines ON medicines
  FOR UPDATE TO authenticated
  USING (profile_id IN (
    SELECT p.id FROM profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ))
  WITH CHECK (profile_id IN (
    SELECT p.id FROM profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));

CREATE POLICY delete_medicines ON medicines
  FOR DELETE TO authenticated
  USING (profile_id IN (
    SELECT p.id FROM profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));

-- RLS Policies for SOS Events
CREATE POLICY select_sos_events ON sos_events
  FOR SELECT TO authenticated
  USING (profile_id IN (
    SELECT p.id FROM profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));

CREATE POLICY insert_sos_events ON sos_events
  FOR INSERT TO authenticated
  WITH CHECK (profile_id IN (
    SELECT p.id FROM profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));

CREATE POLICY update_sos_events ON sos_events
  FOR UPDATE TO authenticated
  USING (profile_id IN (
    SELECT p.id FROM profiles p 
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));

-- RLS Policies for Reminder Logs
CREATE POLICY select_reminder_logs ON reminder_logs
  FOR SELECT TO authenticated
  USING (medicine_id IN (
    SELECT m.id FROM medicines m
    JOIN profiles p ON m.profile_id = p.id
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));

CREATE POLICY insert_reminder_logs ON reminder_logs
  FOR INSERT TO authenticated
  WITH CHECK (medicine_id IN (
    SELECT m.id FROM medicines m
    JOIN profiles p ON m.profile_id = p.id
    WHERE p.id = auth.uid() OR p.owner_id = auth.uid() OR p.id IN (SELECT owner_id FROM profiles WHERE id = auth.uid())
  ));
