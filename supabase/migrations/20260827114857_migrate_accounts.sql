-- ============================================================
-- Move the twelve customer accounts and the one staff account into
-- Supabase Auth, without anybody having to choose a new password.
--
-- PHP hashed passwords with password_hash(), which is bcrypt, and wrote
-- the result to customers.password_hash. Supabase Auth also stores
-- bcrypt, in auth.users.encrypted_password, and reads the $2y$ prefix
-- PHP writes. So the hashes move across as they are: nobody's password
-- is known here, and nobody's password changes.
--
-- Inserting the auth user is all this has to do. The trigger added in
-- the auth_linkage migration sees each new row, finds the customers row
-- with the same email, and claims it — so orders, baskets and event
-- history stay attached to the person they belong to.
--
-- The identities row is not optional. Supabase Auth looks an email
-- sign-in up through auth.identities, so a user with no identity row
-- exists but can never log in.
-- ============================================================

-- ---------------------------------------------------- customers
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  -- These are declared NOT NULL in spirit if not in schema: parts of
  -- Auth read them as strings and fall over on a NULL.
  confirmation_token, recovery_token, email_change, email_change_token_new,
  email_change_token_current, reauthentication_token, phone_change, phone_change_token
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  lower(c.email),
  c.password_hash,
  -- These twelve were shopping on the site before the move, so their
  -- addresses count as confirmed; asking them to click a link in an
  -- email that was never sent would lock them all out.
  now(), c.created_at, now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('name', c.name),
  '', '', '', '', '', '', '', ''
FROM public.customers c
WHERE c.auth_user_id IS NULL
  AND c.password_hash IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(c.email));

-- ---------------------------------------------------- staff
--
-- The admin signed in with a username, not an email, because the PHP
-- login screen asked for one. Supabase Auth is email-based, so the
-- account gets an address built from the username. The password is
-- unchanged.
--
-- etech_role marks this as staff so the trigger does not also file them
-- as a customer.
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change, email_change_token_new,
  email_change_token_current, reauthentication_token, phone_change, phone_change_token
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  lower(a.username) || '@etech.local',
  a.password_hash,
  now(), a.created_at, now(),
  '{"provider":"email","providers":["email"],"etech_role":"admin"}'::jsonb,
  jsonb_build_object('name', a.name),
  '', '', '', '', '', '', '', ''
FROM public.admins a
WHERE a.auth_user_id IS NULL
  AND a.password_hash IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(a.username) || '@etech.local'
  );

-- ---------------------------------------------------- identities
-- One email identity per user just created. Without this the row in
-- auth.users is invisible to sign-in.
-- identities.email is a generated column, computed from identity_data,
-- so it is not in this list — writing to it is an error.
INSERT INTO auth.identities (
  provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
SELECT
  u.id::text,
  u.id,
  jsonb_build_object(
    'sub',            u.id::text,
    'email',          u.email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  NULL, now(), now()
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM auth.identities i
  WHERE i.user_id = u.id AND i.provider = 'email'
);

-- ---------------------------------------------------- link staff
-- Customers were linked by the trigger. Staff were skipped by it on
-- purpose, so that link is made here.
UPDATE public.admins a
SET auth_user_id = u.id
FROM auth.users u
WHERE a.auth_user_id IS NULL
  AND lower(u.email) = lower(a.username) || '@etech.local';
