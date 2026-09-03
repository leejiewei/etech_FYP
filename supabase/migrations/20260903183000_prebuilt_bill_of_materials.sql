-- ============================================================
-- A prebuilt machine that knows what it is made of.
--
-- The Gaming and Office ranges are the shop's own DIY builds: the shop
-- buys the parts, assembles them, and sells the result as one product.
-- So whether one of those machines can be sold at all is not a fact
-- about its own row -- it is a fact about eight other rows. If the
-- motherboard is out, the machine is out, however healthy its own
-- stock_status looks.
--
-- Until now nothing in the database said so. A machine's parts were
-- prose in product_attributes -- cpu = 'Ryzen 5 3400G', motherboard =
-- 'Asus Prime A520M-K' -- with no product_id anywhere. Matching that
-- prose to the catalogue by name was tried before this migration was
-- written, over all 47 distinct specs on the eleven DIY machines, and
-- it is not good enough to sell against:
--
--   * 11 specs matched exactly one product.
--   * 26 matched nothing -- every GPU, every PSU, every chassis.
--   * 7 were ambiguous: '8GB DDR4' matches four different modules,
--     'Core i5-14400' matches the 14400, the 14400F and the machine
--     itself.
--   * 1 was actively wrong: cooler = 'Stock' matched a product called
--     "CPE R120 (Intel stock cooler)", when 'Stock' means the opposite
--     -- no aftermarket cooler is fitted at all.
--
-- A wrong stock badge is worse than no stock badge, so the link is
-- recorded explicitly instead of guessed. That is prebuilt_components.
--
-- The second half of the same problem is upgrades. Every DIY machine's
-- description ends in a line like "Upgrades: +RM499 to RTX 5050 8GB,
-- +RM380 to 1TB Gen4 NVMe". The app has been showing that sentence as a
-- note, deliberately, because an option nobody can price or stock is
-- not an option. prebuilt_upgrades makes them rows: a label, a real
-- price, and a slot they replace, so a customer can tick one on the
-- prebuilt card and confirm the adjusted total in the cart.
--
-- Nothing here changes what an existing machine costs or how any
-- existing cart line behaves. A machine with no rows in these tables
-- carries on exactly as before.
-- ============================================================


-- ------------------------------------------------------------
-- 1. prebuilt_components -- the bill of materials
--
-- One row per slot per machine. "slot" deliberately reuses the same
-- vocabulary as product_attributes.attr_key (cpu, gpu, ram, ...) so a
-- card can line the two up without a translation table.
--
-- Three states a row can be in, and they must stay distinguishable:
--
--   linked       component_id set      -> counts towards the stock rule
--   not stocked  not_stocked = true    -> deliberately has no product
--                                         row (a stock cooler, a PSU
--                                         bundled inside the chassis)
--   pending      neither               -> nobody has said yet
--
-- "pending" is the honest default. While any slot on a machine is
-- pending, the derived answer is incomplete, and prebuilt_availability
-- below reports that rather than pretending. spec_text carries the
-- original prose so the admin screen can show what it is looking for
-- even after the attribute has been edited.
-- ------------------------------------------------------------
create table if not exists prebuilt_components (
  prebuilt_id  integer      not null references products(product_id) on delete cascade,
  slot         varchar(32)  not null,
  spec_text    varchar(255) not null,
  component_id integer      references products(product_id) on delete restrict,
  qty          smallint     not null default 1,
  not_stocked  boolean      not null default false,
  note         varchar(255),
  primary key (prebuilt_id, slot),
  constraint prebuilt_components_qty_positive check (qty > 0),
  -- A slot cannot be both "this product" and "no product exists".
  constraint prebuilt_components_one_state
    check (not (not_stocked and component_id is not null))
);

-- The stock rule joins the other way too -- from a component to every
-- machine that uses it -- so the foreign key needs its own index.
create index if not exists prebuilt_components_component_idx
  on prebuilt_components (component_id)
  where component_id is not null;

comment on table prebuilt_components is
  'Which catalogue products a DIY prebuilt is assembled from. Drives its stock badge.';


-- ------------------------------------------------------------
-- 2. prebuilt_upgrades -- the "Upgrades:" sentence, as rows
--
-- price_delta is what the upgrade adds to the machine's price, never a
-- replacement total: the machine's own price row stays the source of
-- truth for the base, exactly as it is on the shelf.
--
-- component_id is optional and is not where the price comes from. It is
-- there so an upgrade can be greyed out when the part it fits is out of
-- stock; the shop's quoted delta is a bundle price and is deliberately
-- not recalculated from the component's shelf price.
-- ------------------------------------------------------------
create table if not exists prebuilt_upgrades (
  upgrade_id   integer generated always as identity primary key,
  prebuilt_id  integer       not null references products(product_id) on delete cascade,
  slot         varchar(32)   not null,
  label        varchar(120)  not null,
  price_delta  numeric(10,2) not null,
  component_id integer       references products(product_id) on delete set null,
  sort_order   smallint      not null default 0,
  is_active    smallint      not null default 1,
  constraint prebuilt_upgrades_delta_positive check (price_delta >= 0)
);

create index if not exists prebuilt_upgrades_machine_idx
  on prebuilt_upgrades (prebuilt_id, sort_order);

create index if not exists prebuilt_upgrades_component_idx
  on prebuilt_upgrades (component_id)
  where component_id is not null;

comment on table prebuilt_upgrades is
  'Priced upgrade options for a prebuilt, ticked on the product card and confirmed in the cart.';


-- ------------------------------------------------------------
-- 3. cart_item_upgrades -- which upgrades this basket line carries
--
-- Hung off cart_items by its whole primary key, so a line that is
-- removed takes its upgrades with it and an upgrade can never outlive
-- the machine it was chosen for.
-- ------------------------------------------------------------
create table if not exists cart_item_upgrades (
  customer_id integer not null,
  product_id  integer not null,
  upgrade_id  integer not null references prebuilt_upgrades(upgrade_id) on delete cascade,
  primary key (customer_id, product_id, upgrade_id),
  foreign key (customer_id, product_id)
    references cart_items(customer_id, product_id) on delete cascade
);

create index if not exists cart_item_upgrades_upgrade_idx
  on cart_item_upgrades (upgrade_id);

comment on table cart_item_upgrades is
  'Upgrades ticked against one basket line. Cascades away with the line.';


-- ------------------------------------------------------------
-- 4. prebuilt_availability -- the stock rule itself
--
-- Worst component wins: one part out and the machine is out, one part
-- low and the machine is low. Slots marked not_stocked sit out of the
-- vote entirely.
--
-- "pending" is reported rather than assumed away. A caller that sees
-- pending > 0 has not been told enough to draw a badge and should fall
-- back to the machine's own stock_status; once every slot is answered,
-- derived_status is the whole truth. blocking_parts names the culprits,
-- so the admin screen can say *which* part is holding a machine back
-- rather than only that something is.
--
-- security_invoker so the view is read with the caller's own rights
-- rather than the owner's, and the policies above actually apply.
-- ------------------------------------------------------------
create or replace view prebuilt_availability
with (security_invoker = on) as
select
  pc.prebuilt_id,
  count(*) filter (where pc.component_id is not null)                    as linked,
  count(*) filter (where pc.component_id is null and not pc.not_stocked) as pending,
  count(*) filter (where pc.not_stocked)                                 as not_stocked,
  case
    when bool_or(c.stock_status = 'out') then 'out'
    when bool_or(c.stock_status = 'low') then 'low'
    when count(*) filter (where pc.component_id is not null) > 0 then 'in'
    else null
  end as derived_status,
  coalesce(
    string_agg(c.name, ', ' order by c.name)
      filter (where c.stock_status = 'out'),
    ''
  ) as blocking_parts
from prebuilt_components pc
left join products c on c.product_id = pc.component_id
group by pc.prebuilt_id;

comment on view prebuilt_availability is
  'Per-machine stock derived from its components. Trust derived_status only when pending = 0.';


-- ------------------------------------------------------------
-- 5. Who may read and write these
--
-- The bill of materials and the upgrade list are part of the catalogue:
-- readable by anyone, writable only by staff -- the same shape the
-- products and product_attributes policies already have. A basket's
-- upgrades belong to the basket's owner, the same shape as cart_items.
-- Both helpers are wrapped in a sub-select so they are evaluated once
-- per query rather than once per row.
-- ------------------------------------------------------------
alter table prebuilt_components enable row level security;
alter table prebuilt_upgrades   enable row level security;
alter table cart_item_upgrades  enable row level security;

drop policy if exists "bill of materials is public" on prebuilt_components;
create policy "bill of materials is public" on prebuilt_components
  for select to anon, authenticated using (true);

drop policy if exists "staff manage bill of materials" on prebuilt_components;
create policy "staff manage bill of materials" on prebuilt_components
  for all to authenticated
  using ((select is_admin())) with check ((select is_admin()));

drop policy if exists "upgrade options are public" on prebuilt_upgrades;
create policy "upgrade options are public" on prebuilt_upgrades
  for select to anon, authenticated using (is_active = 1);

drop policy if exists "staff manage upgrade options" on prebuilt_upgrades;
create policy "staff manage upgrade options" on prebuilt_upgrades
  for all to authenticated
  using ((select is_admin())) with check ((select is_admin()));

drop policy if exists "own basket upgrades" on cart_item_upgrades;
create policy "own basket upgrades" on cart_item_upgrades
  for all to authenticated
  using (customer_id = (select current_customer_id()))
  with check (customer_id = (select current_customer_id()));

grant select on prebuilt_components, prebuilt_upgrades, prebuilt_availability to anon, authenticated;
grant select, insert, update, delete on cart_item_upgrades to authenticated;
