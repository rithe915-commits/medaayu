-- Add secondary SOS contact column and email column to profiles table
ALTER TABLE public.profiles ADD COLUMN sos_contact_phone_2 TEXT;
ALTER TABLE public.profiles ADD COLUMN email TEXT;
