-- v6: Product enhancements - category, unit_type, arrivage tracking, barcode auto-gen, FK indexes
-- Idempotent: all statements use IF NOT EXISTS

-- STEP 1 — Add category to products
ALTER TABLE products
ADD COLUMN IF NOT EXISTS category TEXT
CHECK (category IN ('homme', 'femme', 'enfant'))
DEFAULT 'homme';

-- STEP 2 — Add unit fields to product_variants
ALTER TABLE product_variants
ADD COLUMN IF NOT EXISTS unit_type TEXT
CHECK (unit_type IN ('piece', 'carton'))
DEFAULT 'piece';

ALTER TABLE product_variants
ADD COLUMN IF NOT EXISTS units_per_carton INTEGER
CHECK (units_per_carton > 0)
DEFAULT NULL;

-- STEP 3 — Add arrivage tracking to inventory
ALTER TABLE inventory
ADD COLUMN IF NOT EXISTS arrivage_id UUID DEFAULT gen_random_uuid();

ALTER TABLE inventory
ADD COLUMN IF NOT EXISTS arrivage_date TIMESTAMPTZ DEFAULT now();

ALTER TABLE inventory
ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(10,2) DEFAULT NULL;

-- STEP 4 — Barcode auto-generation function and trigger
CREATE OR REPLACE FUNCTION generate_barcode()
RETURNS TRIGGER AS $$
DECLARE
  new_barcode TEXT;
  counter INT := 0;
BEGIN
  IF NEW.barcode IS NULL OR NEW.barcode = '' THEN
    LOOP
      new_barcode := 'SHO-' || LPAD(
        (FLOOR(RANDOM() * 900000) + 100000)::TEXT, 6, '0'
      );
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM product_variants WHERE barcode = new_barcode
      );
      counter := counter + 1;
      IF counter > 10 THEN
        RAISE EXCEPTION 'Could not generate unique barcode after 10 attempts';
      END IF;
    END LOOP;
    NEW.barcode := new_barcode;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_barcode ON product_variants;
CREATE TRIGGER trigger_generate_barcode
BEFORE INSERT ON product_variants
FOR EACH ROW EXECUTE FUNCTION generate_barcode();

-- STEP 5 — Add missing FK indexes (23 indexes)
CREATE INDEX IF NOT EXISTS idx_products_supplier_id ON products(supplier_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_transactions_variant_id ON transactions(variant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_store_id ON transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_customer_id ON transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_supplier_id ON transactions(supplier_id);
CREATE INDEX IF NOT EXISTS idx_transactions_invoice_id ON transactions(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoices_store_id ON invoices(store_id);
CREATE INDEX IF NOT EXISTS idx_invoices_user_id ON invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_supplier_id ON invoices(supplier_id);
CREATE INDEX IF NOT EXISTS idx_payments_invoice_id ON payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_supplier_id ON payments(supplier_id);
CREATE INDEX IF NOT EXISTS idx_payments_store_id ON payments(store_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_category_id ON expenses(category_id);
CREATE INDEX IF NOT EXISTS idx_expenses_store_id ON expenses(store_id);
CREATE INDEX IF NOT EXISTS idx_expenses_user_id ON expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_expense_categories_store_id ON expense_categories(store_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_store_id ON user_profiles(store_id);
