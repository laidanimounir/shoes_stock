CREATE OR REPLACE FUNCTION public.approve_purchase_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.purchase_orders;
  v_item record;
  v_invoice_id uuid;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Fetch order
  SELECT * INTO v_order FROM public.purchase_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase order not found';
  END IF;

  IF v_order.status = 'approved' THEN
    RAISE EXCEPTION 'Purchase order already approved';
  END IF;

  IF v_order.status = 'cancelled' THEN
    RAISE EXCEPTION 'Purchase order is cancelled';
  END IF;

  -- Create invoice
  INSERT INTO public.invoices (invoice_number, type, total_amount, paid_amount, discount, status, store_id, supplier_id, user_id)
  VALUES (v_order.order_number, 'in', v_order.total_amount, 0, 0, 'unpaid', v_order.store_id, v_order.supplier_id, v_user_id)
  RETURNING id INTO v_invoice_id;

  -- Insert transactions
  FOR v_item IN
    SELECT poi.variant_id, poi.quantity, poi.unit_price, poi.total_price
    FROM public.purchase_order_items poi
    WHERE poi.purchase_order_id = p_order_id
  LOOP
    INSERT INTO public.transactions (type, variant_id, quantity, unit_price, total_price, store_id, invoice_id, user_id)
    VALUES ('in', v_item.variant_id, v_item.quantity, v_item.unit_price, v_item.total_price, v_order.store_id, v_invoice_id, v_user_id);
  END LOOP;

  -- Update order status
  UPDATE public.purchase_orders SET status = 'approved' WHERE id = p_order_id;

  -- Record purchase price history for each variant
  INSERT INTO public.purchase_price_history (variant_id, supplier_id, store_id, purchase_price, purchased_at, purchase_order_id)
  SELECT poi.variant_id, v_order.supplier_id, v_order.store_id, poi.unit_price, NOW(), v_order.id
  FROM public.purchase_order_items poi
  WHERE poi.purchase_order_id = p_order_id;

  RETURN jsonb_build_object('success', true, 'invoice_id', v_invoice_id, 'order_id', p_order_id);
END;
$$;
