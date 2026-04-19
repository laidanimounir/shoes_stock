-- 1A — expense_categories table
CREATE TABLE IF NOT EXISTS expense_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  store_id uuid REFERENCES stores(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_access" ON expense_categories;
CREATE POLICY "store_access" ON expense_categories
  USING (store_id IN (SELECT store_id FROM user_profiles WHERE id = auth.uid()));

-- 1B — expenses table
CREATE TABLE IF NOT EXISTS expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid REFERENCES expense_categories(id) ON DELETE SET NULL,
  amount numeric NOT NULL CHECK (amount > 0),
  description text,
  payment_method text DEFAULT 'cash' CHECK (payment_method IN ('cash', 'bank', 'mobile')),
  store_id uuid REFERENCES stores(id) ON DELETE CASCADE,
  user_id uuid REFERENCES user_profiles(id) DEFAULT auth.uid(),
  expense_date date DEFAULT current_date,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_access" ON expenses;
CREATE POLICY "store_access" ON expenses
  USING (store_id IN (SELECT store_id FROM user_profiles WHERE id = auth.uid()));

-- 1C — Modify payments table
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'payments'::regclass AND attname = 'payment_type') THEN
    ALTER TABLE payments ADD COLUMN payment_type text DEFAULT 'invoice' CHECK (payment_type IN ('invoice', 'debt_recovery'));
  END IF;
END $$;

-- 1D — RPC: add_expense
CREATE OR REPLACE FUNCTION add_expense(
  p_category_id uuid,
  p_amount numeric,
  p_description text,
  p_payment_method text,
  p_store_id uuid,
  p_expense_date date
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_expense_id uuid;
BEGIN
  INSERT INTO expenses (category_id, amount, description, payment_method, store_id, user_id, expense_date)
  VALUES (p_category_id, p_amount, p_description, p_payment_method, p_store_id, auth.uid(), p_expense_date)
  RETURNING id INTO v_expense_id;
  RETURN v_expense_id;
END;
$$;

-- 1E — RPC: add_debt_recovery_payment
CREATE OR REPLACE FUNCTION add_debt_recovery_payment(
  p_customer_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_store_id uuid,
  p_notes text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Insert payment without invoice_id (debt recovery)
  INSERT INTO payments (customer_id, amount, payment_method, store_id, user_id, payment_type, notes)
  VALUES (p_customer_id, p_amount, p_payment_method, p_store_id, auth.uid(), 'debt_recovery', p_notes);

  -- Balance is already updated by the trigger 'trigger_payment_balance' on the payments table.
  -- The trigger 'update_balance_from_payment' handles INSERT/UPDATE/DELETE.
  -- So we don't need to manually update it here to avoid double deduction.
END;
$$;
