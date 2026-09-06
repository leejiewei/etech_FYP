-- ============================================================
-- One answer, not two.
--
-- prebuilt_availability worked out a DIY machine's stock from its parts,
-- and the shop and the app started showing that. products.stock_status
-- was left where it was. So the two sides of the same business began
-- disagreeing: nine machines read "In Stock" to a customer while the
-- admin Products list, Stock Alerts and the Inventory Velocity score all
-- still read "out" from the products row.
--
-- That is worse than either answer on its own. Stock Alerts exists to
-- say "this is selling and about to run out"; fed a stale column it
-- would have told the shop to restock nine machines that were sitting
-- there available.
--
-- The fix is to stop keeping the answer twice. products.stock_status
-- becomes derived for the eleven DIY machines: whenever a component's
-- stock moves, every machine built from it is recomputed. Everything
-- that reads products.stock_status -- admin, alerts, velocity, the
-- builder, search -- gets the right answer without being changed.
--
-- The cost, stated plainly: staff can no longer set a DIY machine's
-- stock by hand. Its parts decide, and an edit on the product page will
-- be overwritten the next time any of them changes. That is the point --
-- a machine the shop cannot build is not in stock, whatever the row
-- says -- but it is a real change to how the admin panel behaves, and
-- the Prebuilt Parts page is where a wrong answer gets corrected now.
--
-- A machine whose bill of materials is incomplete is left alone
-- entirely. Only fully described machines are recomputed, which is the
-- same rule the customer-facing side already follows.
-- ============================================================


-- ------------------------------------------------------------
-- 1. The recomputation
--
-- Takes a list of machines, or null for all of them. Worst component
-- wins, exactly as prebuilt_availability does it -- deliberately the
-- same arithmetic, because two definitions of "out of stock" is the
-- problem this migration exists to remove.
--
-- Returns how many rows it actually changed, so it can be called by
-- hand to check what a component's arrival would do.
-- ------------------------------------------------------------
create or replace function public.recompute_prebuilt_stock(
  p_prebuilt_ids integer[] default null
)
returns integer
language plpgsql
security definer
set search_path to ''
as $$
DECLARE
  v_changed integer;
BEGIN
  WITH described AS (
    -- Only machines with every slot answered. An unfinished one keeps
    -- whatever its row says, the same fallback the app uses.
    SELECT pc.prebuilt_id
    FROM public.prebuilt_components pc
    WHERE p_prebuilt_ids IS NULL OR pc.prebuilt_id = ANY (p_prebuilt_ids)
    GROUP BY pc.prebuilt_id
    HAVING COUNT(*) FILTER (
             WHERE pc.component_id IS NULL AND NOT pc.not_stocked) = 0
       AND COUNT(*) FILTER (WHERE pc.component_id IS NOT NULL) > 0
  ),
  derived AS (
    SELECT pc.prebuilt_id,
           (CASE
              WHEN bool_or(c.stock_status = 'out') THEN 'out'
              WHEN bool_or(c.stock_status = 'low') THEN 'low'
              ELSE 'in'
            END)::public.stock_status AS status
    FROM public.prebuilt_components pc
    JOIN described d ON d.prebuilt_id = pc.prebuilt_id
    LEFT JOIN public.products c ON c.product_id = pc.component_id
    GROUP BY pc.prebuilt_id
  )
  UPDATE public.products p
  SET stock_status = derived.status,
      updated_at   = now()
  FROM derived
  WHERE p.product_id = derived.prebuilt_id
    AND p.stock_status IS DISTINCT FROM derived.status;

  GET DIAGNOSTICS v_changed = ROW_COUNT;
  RETURN v_changed;
END $$;

comment on function public.recompute_prebuilt_stock(integer[]) is
  'Rewrites products.stock_status for fully described DIY prebuilts from their components.';


-- ------------------------------------------------------------
-- 2. When a part's stock moves
--
-- Fires only on a real change of stock_status, and only for the
-- machines that actually use the part.
--
-- This does not recurse. The rows it goes on to update are the machines
-- themselves, and a machine is never a component of anything -- the
-- Desktops tree is excluded from the bill of materials by construction
-- -- so the second firing finds no dependents and stops.
-- ------------------------------------------------------------
create or replace function public.prebuilt_stock_follows_parts()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
BEGIN
  PERFORM public.recompute_prebuilt_stock(ARRAY(
    SELECT DISTINCT pc.prebuilt_id
    FROM public.prebuilt_components pc
    WHERE pc.component_id = NEW.product_id
  ));
  RETURN NULL;
END $$;

drop trigger if exists products_stock_cascades_to_prebuilts on products;
create trigger products_stock_cascades_to_prebuilts
after update of stock_status on products
for each row
when (old.stock_status is distinct from new.stock_status)
execute function public.prebuilt_stock_follows_parts();


-- ------------------------------------------------------------
-- 3. When the bill of materials itself is edited
--
-- Answering the last pending slot on a machine is the moment it starts
-- being governed by its parts, so that edit has to recompute it too --
-- otherwise the Prebuilt Parts page would look like it had done nothing
-- until some unrelated component happened to move.
-- ------------------------------------------------------------
create or replace function public.prebuilt_parts_changed()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
BEGIN
  PERFORM public.recompute_prebuilt_stock(
    ARRAY[COALESCE(NEW.prebuilt_id, OLD.prebuilt_id)]);
  RETURN NULL;
END $$;

drop trigger if exists prebuilt_components_resync on prebuilt_components;
create trigger prebuilt_components_resync
after insert or update or delete on prebuilt_components
for each row
execute function public.prebuilt_parts_changed();


-- ------------------------------------------------------------
-- 4. Bring the eleven into line now
--
-- Nine of them are expected to move off "out": they were marked by hand
-- before anyone could tell whether the parts were there.
-- ------------------------------------------------------------
select public.recompute_prebuilt_stock();
