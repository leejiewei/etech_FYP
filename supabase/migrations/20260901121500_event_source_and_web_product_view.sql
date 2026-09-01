-- ============================================================
-- Which client a row came from, and making a web view mean what an
-- app view means.
--
-- 20260901093000 fixed who an anonymous visitor is. This fixes a
-- quieter problem in the same table: the website and the app have never
-- meant the same thing by 'view'.
--
--   * In the app, tapping a card records a view and opens the product's
--     own screen. The row means "opened this product".
--
--   * On the website there is no product page. Clicking a card's image
--     recorded a view and did nothing else -- the click led nowhere. So
--     the row meant "clicked a picture for no reason", which almost
--     nobody did. A shopper could read twenty cards and buy one and
--     leave 1 cart_add and 0 views behind, because the card already
--     shows the name, the price and the stock.
--
-- Both meanings landed in the same column of the same table with
-- nothing to tell them apart, and the second one is barely a signal at
-- all. That is most of what is wrong with the 908 views collected so
-- far.
--
-- The website half of the repair is a product detail modal, in
-- web/js/ui.js: a click now opens something, so it means something.
-- This file is the database half -- a column saying which client each
-- row came from, so that the two can be told apart in the analysis
-- whether or not they ever agree again.
-- ============================================================


-- ------------------------------------------------------------
-- source
--
-- 'web' or 'app'. Text with a CHECK rather than a new enum: the two
-- values are a fact about which clients exist today, not a fixed part
-- of the schema, and a third one arriving should be a one-line change
-- rather than an ALTER TYPE.
--
-- NULL is allowed, and means "recorded before 2026-09-01". Nothing can
-- work out after the fact which client those came from, and guessing
-- would be worse than admitting it. Any analysis that compares the two
-- clients has to exclude the null rows; that is the honest position and
-- the column makes it visible instead of hidden.
--
-- Unverified, like anon_id: a client states it and the database takes
-- its word. These rows are insert-only and unreadable from the client
-- side, so the worst a lie does is misfile the liar's own activity.
--
-- No GRANT is needed -- INSERT on all three tables is held at table
-- level, so a new column is insertable as soon as it exists.
-- ------------------------------------------------------------
ALTER TABLE public.events       ADD COLUMN IF NOT EXISTS source text;
ALTER TABLE public.chatbot_logs ADD COLUMN IF NOT EXISTS source text;
ALTER TABLE public.search_logs  ADD COLUMN IF NOT EXISTS source text;

ALTER TABLE public.events
  DROP CONSTRAINT IF EXISTS events_source_check,
  ADD  CONSTRAINT events_source_check CHECK (source IS NULL OR source IN ('web', 'app'));

ALTER TABLE public.chatbot_logs
  DROP CONSTRAINT IF EXISTS chatbot_logs_source_check,
  ADD  CONSTRAINT chatbot_logs_source_check CHECK (source IS NULL OR source IN ('web', 'app'));

ALTER TABLE public.search_logs
  DROP CONSTRAINT IF EXISTS search_logs_source_check,
  ADD  CONSTRAINT search_logs_source_check CHECK (source IS NULL OR source IN ('web', 'app'));

COMMENT ON COLUMN public.events.source IS
  'Which client recorded this: web or app. NULL on rows from before 2026-09-01, whose origin is unrecoverable. Until 2026-09-01 a web view meant "clicked a card image, which did nothing" and an app view meant "opened the product screen"; they are not comparable across that date.';

COMMENT ON COLUMN public.chatbot_logs.source IS 'As events.source.';
COMMENT ON COLUMN public.search_logs.source  IS 'As events.source.';

-- cart_add and purchase are written inside cart_add() and place_order(),
-- which run in the database and cannot see which client called them.
-- Those rows keep a NULL source, and correctly so: the two clients do
-- mean the same thing by a cart add and by a purchase, which is exactly
-- why those two have never had this problem.
