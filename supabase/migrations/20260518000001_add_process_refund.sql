CREATE OR REPLACE FUNCTION process_refund(
  p_invoice_id UUID,
  p_items JSONB,
  p_refund_amount NUMERIC,
  p_reason TEXT DEFAULT '',
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_invoice RECORD;
  v_item JSONB;
  v_new_status TEXT;
  v_log_id UUID;
BEGIN
  SELECT * INTO v_invoice
  FROM public.invoices
  WHERE id = p_invoice_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice not found: %', p_invoice_id;
  END IF;

  IF v_invoice.status = 'refunded' THEN
    RAISE EXCEPTION 'Invoice already refunded: %', p_invoice_id;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    UPDATE public.inventory
    SET quantity = quantity + (v_item->>'quantity')::INT
    WHERE variant_id = (v_item->>'variant_id')::UUID
      AND store_id = v_invoice.store_id;
  END LOOP;

  IF p_refund_amount >= v_invoice.total_amount THEN
    v_new_status := 'refunded';
  ELSE
    v_new_status := 'partial_refund';
  END IF;

  UPDATE public.invoices
  SET
    status = v_new_status,
    paid_amount = GREATEST(0, paid_amount - p_refund_amount),
    updated_at = NOW()
  WHERE id = p_invoice_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.transactions (
      invoice_id, variant_id, store_id,
      quantity, unit_price, total_price, type
    ) VALUES (
      p_invoice_id,
      (v_item->>'variant_id')::UUID,
      v_invoice.store_id,
      -((v_item->>'quantity')::INT),
      (v_item->>'unit_price')::NUMERIC,
      -((v_item->>'quantity')::INT * (v_item->>'unit_price')::NUMERIC),
      'refund'
    );
  END LOOP;

  INSERT INTO public.activity_logs (
    user_id, action_type, description
  ) VALUES (
    p_user_id,
    'REFUND_PROCESSED',
    jsonb_build_object(
      'invoice_id', p_invoice_id,
      'refund_amount', p_refund_amount,
      'reason', p_reason,
      'new_status', v_new_status,
      'items', p_items
    )::TEXT
  ) RETURNING id INTO v_log_id;

  RETURN jsonb_build_object(
    'success', true,
    'new_status', v_new_status,
    'log_id', v_log_id
  );

EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$$;
