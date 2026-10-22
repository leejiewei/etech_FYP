-- New brands and categories can now be added from the staff console
-- (Brands & Categories page). Every existing row was loaded with its id
-- written out, so the identity sequences behind brand_id and category_id
-- were never moved: the first brand added would be given id 1 and be
-- refused as a duplicate. Start each sequence after the highest id in use.

select setval(pg_get_serial_sequence('public.brands', 'brand_id'),
              (select coalesce(max(brand_id), 1) from public.brands));

select setval(pg_get_serial_sequence('public.categories', 'category_id'),
              (select coalesce(max(category_id), 1) from public.categories));
