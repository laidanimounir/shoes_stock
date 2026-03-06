-- ============================================================
-- Add buy_price column to product_variants
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

ALTER TABLE product_variants
ADD COLUMN IF NOT EXISTS buy_price numeric DEFAULT 0.0;
