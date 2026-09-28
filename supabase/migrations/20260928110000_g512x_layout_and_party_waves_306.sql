-- The shop confirmed the two open peripheral questions (28 Sep):
-- the Logitech G512X is the 98% layout, and the unnamed Salpido Party Waves
-- (RM78) is the Party Waves 306. Both prices stand: G512X RM799,
-- G512 Carbon RM369.
insert into public.product_attributes (product_id, attr_key, attr_value) values (4416, 'layout', '98%');
update public.products set description = 'Keyboard. Black. Switch: Brown. Layout: 98%. Connection: Wired.' where product_id = 4416;
update public.products set name = 'Salpido Party Waves 306' where product_id = 4863;