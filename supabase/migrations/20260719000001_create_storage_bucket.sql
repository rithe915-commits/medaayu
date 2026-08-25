-- Create the public bucket medaayu_photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('medaayu_photos', 'medaayu_photos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies for select/insert/update/delete
CREATE POLICY "Public Access Objects" ON storage.objects FOR SELECT USING (bucket_id = 'medaayu_photos');
CREATE POLICY "Authenticated Insert Objects" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'medaayu_photos');
CREATE POLICY "Authenticated Update Objects" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'medaayu_photos');
