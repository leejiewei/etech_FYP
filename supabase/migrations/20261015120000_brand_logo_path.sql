-- A brand's logo, as the full URL of a PNG served by the website
-- (web/images/brands/), the same way products.image_path works. NULL
-- means we have no proper logo, and the clients show the name alone.
alter table public.brands add column if not exists logo_path text;
comment on column public.brands.logo_path is
  'Full URL of the brand logo PNG on the website; NULL = show the name only.';
