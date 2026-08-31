-- A second staff account, for the shop's owner.
--
-- Built the same way as the migrated one in 20260827114857: a row in
-- auth.users, the email identity that makes it possible to sign in, and
-- the public.admins row that is_admin() actually reads.
--
-- Unlike that migration, the email is a real one rather than
-- username@etech.local, because this account is being created here rather
-- than carried over from the PHP login screen.
--
-- etech_role 'admin' matters: handle_new_auth_user() files every new auth
-- user as a customer unless it sees that flag. Without it this account
-- would end up as staff AND a customer.

WITH new_user AS (
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new,
    email_change_token_current, reauthentication_token, phone_change, phone_change_token
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'chlee9580@gmail.com',
    -- bcrypt, the same scheme PHP's password_hash() produced, so this row
    -- is indistinguishable from a migrated one.
    extensions.crypt('admin123', extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"],"etech_role":"admin"}'::jsonb,
    jsonb_build_object('name', 'Lee Jie Wei'),
    '', '', '', '', '', '', '', ''
  )
  RETURNING id, email
),
new_identity AS (
  -- Without this the auth.users row exists but cannot sign in.
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
  FROM new_user u
  RETURNING user_id
)
INSERT INTO public.admins (username, password_hash, name, auth_user_id)
SELECT
  'Lee Jie Wei',
  -- The legacy column. Nothing signs in through it any more -- Supabase
  -- Auth owns the password now -- but it is NOT NULL and the migration
  -- that moved staff across reads it, so it is filled in to match.
  extensions.crypt('admin123', extensions.gen_salt('bf')),
  'Lee Jie Wei',
  u.id
FROM new_user u;
