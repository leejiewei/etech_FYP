-- ============================================================
-- Direct client access — the shop front, the Flutter app and the admin
-- panel all talk to Supabase themselves. There is no PHP in between any
-- more, so everything the old PHP used to enforce has to be enforced by
-- the database instead.
--
-- What PHP was doing, and where each job goes now:
--
--   who is signed in          $_SESSION['customer_id']  ->  auth.uid()
--   "this row is mine"        WHERE customer_id = ?     ->  RLS policy
--   admin-only pages          requireAdmin()            ->  is_admin()
--   cost_price is not public  a second MySQL login      ->  column GRANTs
--   checkout is all-or-none   dbBegin()/dbCommit()      ->  place_order()
--   sums for the dashboard    GROUP BY in a .php file   ->  admin_* views
--
-- The previous migration (…_etech_rls.sql) turned RLS on for every table
-- and deliberately wrote no policies, because the only reader was PHP
-- connecting as the table owner. This file writes the policies that were
-- left as a comment at the bottom of that file, and a good deal more.
-- ============================================================


-- ============================================================
-- 1. Accounts move to Supabase Auth
--
-- Passwords were checked by PHP's password_verify() against
-- customers.password_hash. They are now checked by Supabase Auth
-- against auth.users, because that is the only thing that can hand the
-- browser a JWT — and a JWT is the only thing RLS can read.
--
-- The customers table stays exactly where it is. Every order, basket
-- row and event points at customer_id, and rewriting all of those to a
-- uuid would be a large change for no gain. Instead each row gains a
-- link to the auth user that signs in as it.
-- ============================================================

ALTER TABLE public.customers
  ADD COLUMN auth_user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.admins
  ADD COLUMN auth_user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE;

-- Supabase Auth owns passwords now. The old hashes are copied into
-- auth.users by the data migration that follows this one and are no
-- longer read by anything, so the column stops being required.
ALTER TABLE public.customers ALTER COLUMN password_hash DROP NOT NULL;
ALTER TABLE public.admins    ALTER COLUMN password_hash DROP NOT NULL;


-- ------------------------------------------------------------
-- Who is asking?
--
-- auth.uid() is the signed-in user's uuid, read out of the JWT the
-- client sent. These two turn that into the answers the policies below
-- actually need.
--
-- SECURITY DEFINER because both read tables that are themselves behind
-- RLS — without it, is_admin() would need to read admins, whose policy
-- calls is_admin(), and Postgres would recurse. search_path is pinned
-- to nothing so a caller cannot shadow "public" with a table of theirs.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_customer_id()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT c.customer_id FROM public.customers c WHERE c.auth_user_id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (SELECT 1 FROM public.admins a WHERE a.auth_user_id = auth.uid())
$$;

REVOKE EXECUTE ON FUNCTION public.current_customer_id() FROM public;
REVOKE EXECUTE ON FUNCTION public.is_admin()            FROM public;
GRANT  EXECUTE ON FUNCTION public.current_customer_id() TO anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.is_admin()            TO anon, authenticated;


-- ------------------------------------------------------------
-- Registering.
--
-- The old api/auth.php?action=register inserted the customer row
-- itself. Signing up is now supabase.auth.signUp(), which only writes
-- to auth.users — so a trigger makes the matching customers row, and
-- the display name rides along in the sign-up metadata.
--
-- Staff are created by hand and flagged in raw_app_meta_data, so an
-- admin does not also become a customer.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF (NEW.raw_app_meta_data ->> 'etech_role') = 'admin' THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.customers AS c (name, email, auth_user_id)
  VALUES (
    COALESCE(NULLIF(btrim(NEW.raw_user_meta_data ->> 'name'), ''), split_part(NEW.email, '@', 1)),
    lower(NEW.email),
    NEW.id
  )
  -- An email that is already in the table is one of the twelve accounts
  -- carried over from before the move. Claim it, so the person keeps
  -- their orders — but only if nobody has claimed it already.
  ON CONFLICT (email) DO UPDATE
    SET auth_user_id = EXCLUDED.auth_user_id
    WHERE c.auth_user_id IS NULL;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();
