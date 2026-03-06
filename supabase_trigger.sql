-- ============================================================
-- Shoes Stock - Inventory Update Trigger
-- ============================================================
-- This script creates a PostgreSQL function + trigger that
-- automatically updates the inventory table whenever a
-- transaction is inserted.
--
-- type = 'in'  → inventory quantity INCREASES (purchase)
-- type = 'out' → inventory quantity DECREASES (sale)
--
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- Step 1: Create the function
CREATE OR REPLACE FUNCTION update_inventory_on_transaction()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if an inventory record already exists for this variant + store
  IF EXISTS (
    SELECT 1 FROM inventory
    WHERE variant_id = NEW.variant_id AND store_id = NEW.store_id
  ) THEN
    -- Update existing record
    IF NEW.type = 'in' THEN
      UPDATE inventory
      SET quantity = quantity + NEW.quantity,
          updated_at = now()
      WHERE variant_id = NEW.variant_id AND store_id = NEW.store_id;
    ELSIF NEW.type = 'out' THEN
      UPDATE inventory
      SET quantity = quantity - NEW.quantity,
          updated_at = now()
      WHERE variant_id = NEW.variant_id AND store_id = NEW.store_id;
    END IF;
  ELSE
    -- Create new inventory record
    INSERT INTO inventory (variant_id, store_id, quantity)
    VALUES (
      NEW.variant_id,
      NEW.store_id,
      CASE WHEN NEW.type = 'in' THEN NEW.quantity ELSE -NEW.quantity END
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Drop old trigger if exists
DROP TRIGGER IF EXISTS trigger_update_inventory ON transactions;

-- Step 3: Create the trigger
CREATE TRIGGER trigger_update_inventory
  AFTER INSERT ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_inventory_on_transaction();

-- Note: Realtime is already enabled for the inventory table.
