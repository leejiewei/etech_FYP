-- The shop confirmed the Logitech G512X is wired (its layout, 75% or 98%,
-- is still to be confirmed).
insert into public.product_attributes (product_id, attr_key, attr_value) values (4416, 'connection', 'Wired');
update public.products set description = 'Keyboard. Black. Switch: Brown. Connection: Wired.' where product_id = 4416;
