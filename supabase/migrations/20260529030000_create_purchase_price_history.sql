CREATE TABLE IF NOT EXISTS public.purchase_price_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  variant_id UUID NOT NULL REFERENCES public.product_variants(id),
  supplier_id UUID REFERENCES public.suppliers(id),
  store_id UUID REFERENCES public.stores(id),
  purchase_price numeric NOT NULL,
  purchased_at timestamptz DEFAULT now(),
  purchase_order_id UUID REFERENCES public.purchase_orders(id)
);

CREATE INDEX IF NOT EXISTS idx_pph_variant ON public.purchase_price_history(variant_id);

CREATE OR REPLACE FUNCTION public.get_price_history(p_variant_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(h) ORDER BY h.purchased_at DESC), '[]'::json)
  INTO result
  FROM (
    SELECT
      pph.purchase_price,
      pph.purchased_at,
      s.full_name AS supplier_name,
      LAG(pph.purchase_price) OVER (ORDER BY pph.purchased_at) AS prev_price
    FROM public.purchase_price_history pph
    LEFT JOIN public.suppliers s ON s.id = pph.supplier_id
    WHERE pph.variant_id = p_variant_id
    ORDER BY pph.purchased_at DESC
  ) h;

  RETURN result;
END;
$$;
