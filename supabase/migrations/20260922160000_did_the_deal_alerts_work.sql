-- ============================================================
-- Did the deal alerts work?
--
-- admin_create_deal() messages the customers whose behaviour says they
-- want a product. This is the other half of that claim: for every one of
-- those messages, what the customer did next. It is the evidence
-- Objective 1 is reported on -- alerts sent, opened, followed back to the
-- product, turned into a purchase.
--
-- Why a function and not a policy on notifications. Staff cannot read
-- notifications today (only "own notifications"), and a staff SELECT
-- policy would hand them every order message word for word. This returns
-- only the deal alerts and only what the report needs: when it was sent,
-- whether and when it was opened, and whether the customer came back to
-- view or buy that product afterwards. It is SECURITY DEFINER behind the
-- same is_admin() check as admin_create_deal().
--
-- "Afterwards" means within p_days of the alert being sent, 7 by
-- default -- a week covers a typical deal window and stops a purchase a
-- month later being credited to a message the customer has forgotten.
-- The reason a customer was picked is read back from the title
-- admin_create_deal() gave the message, which is where it is recorded.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_deal_alert_results(p_days integer DEFAULT 7)
RETURNS TABLE (
  notification_id integer,
  customer_id     integer,
  customer_name   text,
  product_id      integer,
  product_name    text,
  reason          text,
  sent_at         timestamptz,
  read_at         timestamptz,
  viewed_after    boolean,
  bought_after    boolean,
  bought_at       timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT (SELECT public.is_admin()) THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    n.notification_id,
    n.customer_id,
    c.name::text,
    n.product_id,
    p.name::text,
    CASE
      WHEN n.title LIKE '%saved%'   THEN 'saved'
      WHEN n.title LIKE '%cart%'    THEN 'carted'
      ELSE 'viewed'
    END,
    n.created_at,
    n.read_at,
    EXISTS (SELECT 1 FROM public.events e
            WHERE e.customer_id = n.customer_id
              AND e.product_id  = n.product_id
              AND e.event_type  = 'view'
              AND e.created_at >  n.created_at
              AND e.created_at <= n.created_at + make_interval(days => p_days)),
    bought.first_at IS NOT NULL,
    bought.first_at
  FROM public.notifications n
  JOIN public.customers c ON c.customer_id = n.customer_id
  JOIN public.products  p ON p.product_id  = n.product_id
  LEFT JOIN LATERAL (
    SELECT min(e.created_at) AS first_at
    FROM public.events e
    WHERE e.customer_id = n.customer_id
      AND e.product_id  = n.product_id
      AND e.event_type  = 'purchase'
      AND e.created_at >  n.created_at
      AND e.created_at <= n.created_at + make_interval(days => p_days)
  ) bought ON true
  WHERE n.kind = 'deal_started'
  ORDER BY n.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_deal_alert_results(integer) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.admin_deal_alert_results(integer) TO authenticated;
