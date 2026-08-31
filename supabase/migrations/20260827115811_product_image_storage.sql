-- ============================================================
-- Somewhere to put product photos.
--
-- admin/product_edit.php accepted an upload, resized it with GD and
-- wrote the file into web/uploads/. That only worked because there was
-- a PHP process with a filesystem behind it. There isn't one now, so
-- the photos go to Supabase Storage instead and products.image_path
-- holds the public URL of the object rather than a path inside the
-- website folder.
--
-- Nothing has to be moved across: no product has a photo yet (334 of
-- 334 have image_path NULL), so this bucket starts empty and the first
-- upload through the new admin page is the first thing in it.
--
-- The bucket is public to read, because a product photo on a shop front
-- is about as public as a thing can be, and that lets both the website
-- and the Flutter app show it with no token at all. Writing is another
-- matter and is limited to staff, by the same is_admin() the rest of
-- the panel is gated on.
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  5242880,                                        -- 5MB, the limit the PHP enforced
  ARRAY['image/jpeg', 'image/png', 'image/webp']  -- the three types it accepted
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "product images are public" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'product-images');

CREATE POLICY "staff add product images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'product-images' AND (SELECT public.is_admin()));

CREATE POLICY "staff replace product images" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'product-images' AND (SELECT public.is_admin()))
  WITH CHECK (bucket_id = 'product-images' AND (SELECT public.is_admin()));

CREATE POLICY "staff remove product images" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'product-images' AND (SELECT public.is_admin()));
