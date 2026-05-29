CREATE OR REPLACE FUNCTION public.get_supplier_comparison(
  p_store_id UUID DEFAULT NULL,
  p_variant_id UUID DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(s) ORDER BY s.last_price), '[]'::json)
  INTO result
  FROM (
    SELECT
      s.id AS supplier_id,
      s.full_name AS supplier_name,
      pph.purchase_price AS last_price,
      AVG(pph.purchase_price) AS avg_price,
      MIN(pph.purchase_price) AS min_price,
      MAX(pph.purchase_price) AS max_price,
      MAX(pph.purchased_at) AS last_purchase_date,
      COUNT(pph.id)::INT AS total_purchases
    FROM public.suppliers s
    JOIN public.purchase_price_history pph ON pph.supplier_id = s.id
    WHERE (p_variant_id IS NULL OR pph.variant_id = p_variant_id)
      AND (p_store_id IS NULL OR pph.store_id = p_store_id)
    GROUP BY s.id, s.full_name
    ORDER BY last_price ASC
  ) s;

  RETURN result;
END;
$$;
