ALTER TABLE public.purchase_orders ADD COLUMN IF NOT EXISTS received_at timestamptz;

ALTER TABLE public.purchase_order_items ADD COLUMN IF NOT EXISTS received_qty int DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_po_status ON public.purchase_orders(status);

CREATE OR REPLACE FUNCTION public.confirm_purchase_order(p_po_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.purchase_orders;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_order FROM public.purchase_orders WHERE id = p_po_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase order not found';
  END IF;

  IF v_order.status NOT IN ('draft', 'pending') THEN
    RAISE EXCEPTION 'Purchase order cannot be confirmed (current status: %)', v_order.status;
  END IF;

  UPDATE public.purchase_orders SET status = 'confirmed', updated_at = now() WHERE id = p_po_id;

  RETURN jsonb_build_object('success', true, 'order_id', p_po_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.receive_purchase_order_items(p_po_id uuid, p_items json)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.purchase_orders;
  v_item json;
  v_variant_id uuid;
  v_received_qty int;
  v_ordered_qty int;
  v_current_received int;
  v_user_id uuid;
  v_all_received boolean := true;
  v_any_received boolean := false;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_order FROM public.purchase_orders WHERE id = p_po_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase order not found';
  END IF;

  IF v_order.status NOT IN ('confirmed', 'partially_received') THEN
    RAISE EXCEPTION 'Purchase order cannot receive stock (current status: %)', v_order.status;
  END IF;

  FOR v_item IN SELECT * FROM json_array_elements(p_items)
  LOOP
    v_variant_id := (v_item->>'variant_id')::uuid;
    v_received_qty := (v_item->>'received_qty')::int;

    SELECT quantity INTO v_ordered_qty
    FROM public.purchase_order_items
    WHERE purchase_order_id = p_po_id AND variant_id = v_variant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant % not found in purchase order', v_variant_id;
    END IF;

    IF v_received_qty < 0 THEN
      RAISE EXCEPTION 'Received quantity cannot be negative';
    END IF;

    UPDATE public.purchase_order_items
    SET received_qty = v_received_qty
    WHERE purchase_order_id = p_po_id AND variant_id = v_variant_id
    RETURNING received_qty INTO v_current_received;

    IF v_current_received >= v_ordered_qty THEN
      v_any_received := true;
    ELSE
      v_all_received := false;
      IF v_current_received > 0 THEN
        v_any_received := true;
      END IF;
    END IF;

    PERFORM public.adjust_inventory(
      v_variant_id,
      v_order.store_id,
      v_received_qty,
      'purchase'
    );
  END LOOP;

  IF v_all_received AND v_any_received THEN
    UPDATE public.purchase_orders
    SET status = 'received', received_at = now(), updated_at = now()
    WHERE id = p_po_id;
  ELSIF v_any_received THEN
    UPDATE public.purchase_orders
    SET status = 'partially_received', received_at = now(), updated_at = now()
    WHERE id = p_po_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'order_id', p_po_id);
END;
$$;
