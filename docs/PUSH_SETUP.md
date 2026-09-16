# Turning on push notifications

Everything in the shop is built and deployed. Push is **off** because it
needs three things only the account holder can create: a Firebase
project, a service account key, and the Supabase service-role key.

Until those exist, nothing misbehaves. The app builds and sells as it
always did, the in-app bell still works, and the database trigger checks
for its settings, finds none, writes a line to the log and returns. That
is deliberate — a shop that cannot take an order because a Firebase
project has not been made yet would be a worse bug than a quiet phone.

---

## What already exists

| piece | where | state |
|---|---|---|
| `device_tokens` table | `20260916190000_notifications_that_reach_a_closed_app.sql` | live |
| `register_device_token()` / `forget_device_token()` | same migration | live |
| `trg_notify_push` on `notifications` | same migration | live, dormant |
| `push-notify` Edge Function | `supabase/functions/push-notify/` | deployed, ACTIVE |
| Flutter `Push` service | `mobile/lib/services/push.dart` | built, dormant |
| `firebase_options.dart` | `mobile/lib/` | **placeholder** |

---

## Step 1 — Make the Firebase project

1. <https://console.firebase.google.com> → **Add project**. Any name.
   Google Analytics is not needed and can be turned off.
2. Inside the project: **Add app → Android**.
3. Android package name — this must match exactly, or tokens are issued
   against a project that will never be asked to deliver to them:

   ```
   com.etech.etech_mobile
   ```

4. Download `google-services.json` when offered. Keep it; step 2 may not
   need it, but step 4 might.

## Step 2 — Point the app at it

From the `mobile/` directory:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

This **overwrites `mobile/lib/firebase_options.dart`**, which is the
point — the placeholder currently in there holds empty strings.

> **One edit is needed afterwards.** The generated file has no
> `isConfigured` getter, and `services/push.dart` reads it. Add this back
> inside the generated `DefaultFirebaseOptions` class or the app will not
> compile:
>
> ```dart
> static bool get isConfigured => android.appId.isNotEmpty;
> ```
>
> (The generated file names its Android entry `android`, not `_android`.)

Then confirm nothing broke:

```bash
flutter analyze
flutter build apk --release
```

## Step 3 — Give the Edge Function a key to send with

1. Firebase console → **⚙ Project settings → Service accounts** →
   **Generate new private key**. A JSON file downloads.
2. Supabase dashboard → **Edge Functions → push-notify → Secrets**, or:

   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
   ```

   The whole JSON goes in as one value. The function parses it and only
   ever reads `project_id`, `client_email` and `private_key`.

**This file is a credential.** Anyone holding it can send notifications
that look like they came from the shop. It does not belong in git, in the
repo folder, or in a chat message.

## Step 4 — Let the database call the function

The trigger reads both settings from Vault, by name. Run this once in the
SQL editor, with your own service-role key pasted in
(**Project settings → API keys → `service_role`** — the secret one, not
the publishable one):

```sql
select vault.create_secret(
  'https://asawhkjvturznjitsqfk.supabase.co/functions/v1/push-notify',
  'push_function_url',
  'Where notify_push() posts when a notification row is written'
);

select vault.create_secret(
  'PASTE_THE_SERVICE_ROLE_KEY_HERE',
  'push_service_key',
  'Authorises notify_push() to call the push-notify Edge Function'
);
```

To change one later, `vault.update_secret()` — `create_secret` will
refuse a name that already exists.

---

## Checking it works

1. Sign in on the phone. A token should appear:

   ```sql
   select customer_id, platform, created_at from public.device_tokens;
   ```

   Nothing there means the app never got a token — check that step 2's
   `isConfigured` returns true, and that the notification permission was
   granted when the app asked.

2. **Close the app completely.** Not backgrounded — closed. This is the
   whole point of the feature and the only state that proves it.

3. From the staff console, approve a payment or mark an order ready. The
   phone should buzz within a second or two.

4. If it does not, the function's own log says why:

   ```sql
   select * from net._http_response order by created desc limit 5;
   ```

   plus the Edge Function logs in the dashboard. The common answers are
   `FCM_SERVICE_ACCOUNT is not set` (step 3 missed) and
   `customer N has no registered device` (step 1's package name does not
   match, so the token belongs to a different project).

---

## Things worth knowing

**A push is a copy, never the record.** The `notifications` row is
written by the database inside the same transaction as the staff action
that caused it. The push is shouted at a handset afterwards and is
allowed to fail — dead token, flat battery, permission denied — because
the bell still shows the message when the app next opens. Nothing in the
shop should ever be built to depend on a push having arrived.

**A token identifies an installation, not a person.** `device_tokens` is
unique on the token and `register_device_token()` conflicts on it, so a
handset that changes hands moves to whoever signed in last. Without that,
one customer's phone would keep buzzing with another's orders.

**Dead tokens clean themselves up.** When Google answers `UNREGISTERED`
the function deletes the row. That is the only tidying this table gets,
because nothing else ever learns that an app was uninstalled.

**Customers who only use the website have no token**, and the function
logs `no registered device` and stops. That is the ordinary case, not a
fault.
