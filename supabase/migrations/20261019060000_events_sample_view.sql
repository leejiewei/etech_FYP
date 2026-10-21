-- For the FYP report screenshot (Figure 4.2): the newest five rows of each
-- event type, so one screen shows view, cart_add, wishlist_add and purchase
-- together. Staff-only: security_invoker keeps the events policies, and the
-- API roles cannot read it at all.
create view public.events_sample
with (security_invoker = true) as
select event_id, customer_id, product_id, product_name, event_type, source, created_at
from (
  select e.event_id, e.customer_id, e.product_id, p.name as product_name,
         e.event_type, e.source, e.created_at,
         row_number() over (partition by e.event_type order by e.created_at desc) as rn
  from public.events e
  left join public.products p on p.product_id = e.product_id
  where e.customer_id is not null
) t
where rn <= 5
order by event_type, created_at desc;

revoke all on public.events_sample from anon, authenticated;
