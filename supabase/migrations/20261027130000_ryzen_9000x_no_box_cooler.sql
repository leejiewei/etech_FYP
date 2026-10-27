-- The Ryzen 5 9600X and Ryzen 7 9700X were recorded as coming with a cooler
-- in the box. They do not: AMD lists the Ryzen 9000 X parts' thermal
-- solution as "Not Included". The PC Builder lets a build go without a
-- cooler when coolerIncluded is "Yes", so these two would have let a
-- customer order a CPU with nothing to cool it.
--
-- Applied live on 27 Oct 2026 by hand; kept here so the history is complete.
update product_attributes
   set attr_value = 'No'
 where attr_key = 'coolerIncluded'
   and product_id in (2004, 2006);
