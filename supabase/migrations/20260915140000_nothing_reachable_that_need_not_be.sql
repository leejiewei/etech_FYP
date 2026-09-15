-- ============================================================
-- Taking four functions and one view out of the public API.
--
-- Follow-up to 20260915130000_a_backup_is_not_a_public_table.sql, from
-- the same advisor run. None of this is a leak -- each item below was
-- tested as the role in question first, and the findings are recorded
-- here because "we checked and it was fine" is worth writing down too.
-- It is the API surface that is wrong, not the data behind it.
--
-- Three trigger functions and one maintenance function are exposed at
-- /rest/v1/rpc/ because this project grants EXECUTE across the schema:
--
--   handle_new_auth_user()          trigger, refuses: "trigger functions
--   prebuilt_parts_changed()        trigger,  can only be called as
--   prebuilt_stock_follows_parts()  trigger,  triggers"
--   recompute_prebuilt_stock(int[]) runs when anon calls it
--
-- The three trigger functions cannot be made to do anything -- Postgres
-- refuses them by name. They come off the API because a published RPC
-- endpoint that only ever errors is still an endpoint, and the next
-- reader should not have to rediscover that it is harmless.
--
-- recompute_prebuilt_stock() really does run for a stranger. Tested: it
-- changed 0 rows and left stock_status 'in' as 'in'. It cannot do worse,
-- because it derives each prebuilt's status from its components rather
-- than taking a value -- the same reason prebuilt stock is never hand
-- edited. So the exposure is a stranger making the server do arithmetic
-- it was going to do anyway. Nothing in the repository calls it over
-- rpc, and no other database function calls it by name, so nothing loses
-- an endpoint it was using.
--
-- REVOKE is safe for all four. A trigger's EXECUTE privilege is checked
-- when the trigger is created, not each time it fires, and all four are
-- SECURITY DEFINER owned by postgres, so anything calling them from
-- inside the database keeps working.
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.handle_new_auth_user()                 FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prebuilt_parts_changed()               FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prebuilt_stock_follows_parts()         FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.recompute_prebuilt_stock(integer[])    FROM public, anon, authenticated;


-- ============================================================
-- current_customer_id() is deliberately left alone.
--
-- The advisor flags it as anon-executable too, and it is the one flag on
-- that list that must not be acted on. Ten RLS policies call it, and
-- three of those are anon policies -- "anyone may record a view" on
-- events, "anyone may log a chat" on chatbot_logs, "anyone may record a
-- search" on search_logs. A policy calls the function as the querying
-- role, so revoking EXECUTE from anon would stop signed-out visitors
-- writing the very rows Objective 1 is measured on.
--
-- It is also harmless: called by anon it returns NULL, because it
-- resolves auth.uid() and there is no user. Tested.
-- ============================================================


-- ============================================================
-- admin_customer_activity: drop the grant it never needed.
--
-- Added earlier today in 20260915120000. The GRANT names authenticated
-- only, but anon holds SELECT as well, from the same schema-wide grant
-- that left the backup tables open -- it applies to a new view the
-- moment the view exists.
--
-- Not a leak, and tested as anon: the view is security_invoker, so it
-- stops at "permission denied for table customers" long before a row is
-- shaped. But every other admin_ view in this schema is unreadable to
-- anon at the grant, and this one should not be the exception that makes
-- a reader wonder whether it was meant.
-- ============================================================

REVOKE ALL ON public.admin_customer_activity FROM anon;
