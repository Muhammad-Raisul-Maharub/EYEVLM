-- =============================================
-- EyeVLM Supabase Schema Update
-- Multi-Image Support (image_urls JSONB column)
-- =============================================

-- 1. Add image_urls JSONB column to scans table
-- This stores an array of image URLs for multi-image support
ALTER TABLE public.scans 
ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]'::jsonb;

-- 2. Migrate existing single image_url data to image_urls array
-- This ensures backward compatibility
UPDATE public.scans 
SET image_urls = jsonb_build_array(image_url) 
WHERE image_url IS NOT NULL 
  AND image_url != ''
  AND (image_urls IS NULL OR image_urls = '[]'::jsonb);

-- 3. Add an index for faster queries on image_urls
CREATE INDEX IF NOT EXISTS idx_scans_image_urls 
ON public.scans USING GIN (image_urls);

-- 4. Verify the migration (run this to check)
-- SELECT id, image_url, image_urls FROM public.scans LIMIT 10;

-- =============================================
-- Optional: Add device_id for collector tracking
-- (Recommended for data collection traceability)
-- =============================================

-- Uncomment if you want to track which device collected data
-- ALTER TABLE public.scans 
-- ADD COLUMN IF NOT EXISTS device_id TEXT;

-- ALTER TABLE public.scans 
-- ADD COLUMN IF NOT EXISTS collector_name TEXT;
