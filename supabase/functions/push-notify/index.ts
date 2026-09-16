// Shouting a notification at a phone that is not running the app.
//
// The bell in the app is a Realtime subscription, which is a websocket
// held open by a running process. Close the app and it closes with it, so
// the customer who wanted to be told without opening the app was exactly
// the customer who could not be. Android will not let an app wake itself;
// reaching a closed one means Firebase Cloud Messaging, and FCM will not
// take a request from a phone or a browser -- it wants a server holding a
// service account. That is what this is.
//
// WHY THE REQUEST CARRIES ONLY AN ID
//
// The database trigger that calls this posts {notification_id} and
// nothing else. pg_net keeps every request body and response it has ever
// sent in two tables in the same database, so putting a customer's order
// news in that body would copy it into a third place nobody thinks of as
// holding it. This function reads the row itself, with the service-role
// key it already has, and the words go straight to Google.
//
// WHY A FAILURE HERE IS QUIET
//
// The notification row is the record and it is already written and
// already committed by the time this runs. The push is a copy of it
// shouted at a handset. If Google is down, or the token is dead, or this
// function has a bad day, the customer still sees the message the moment
// they open the app. So every failure below is logged and swallowed, and
// this function always answers 200 to the trigger -- there is nothing the
// database could usefully do with an error, and pg_net would only write
// it to a table nobody reads.

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";

// An access token minted from the service account lasts an hour. Edge
// functions keep their instance warm between calls, so caching it turns
// the common case -- a burst of notifications as staff work through the
// morning's orders -- into one round trip to Google instead of one per
// message. Sixty seconds of headroom so a token never expires mid-flight.
let cachedToken: { value: string; expiresAt: number } | null = null;

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT is not set");

  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error("FCM_SERVICE_ACCOUNT is missing project_id, client_email or private_key");
  }
  return parsed;
}

// ------------------------------------------------------------
// Signing in as the service account.
//
// Google's own libraries do this and none of them run here, so it is
// done by hand: build a JWT asserting "I am this service account and I
// would like to send messages", sign it with the account's private key,
// and exchange it at the token endpoint for a bearer token.
// ------------------------------------------------------------
function base64url(bytes: Uint8Array | string): string {
  const data = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  return btoa(String.fromCharCode(...data))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// The key arrives as PEM text. Escaped newlines are a fact of life in
// environment variables -- a service account JSON pasted into a secret
// usually has "\n" as two characters -- so both spellings are accepted.
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");

  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const account = serviceAccount();
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: account.client_email,
    scope: FCM_SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  }));

  const key = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));

  const assertion = `${header}.${claims}.${base64url(new Uint8Array(signature))}`;

  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`token endpoint said ${response.status}: ${await response.text()}`);
  }

  const body = await response.json();
  cachedToken = { value: body.access_token, expiresAt: now + (body.expires_in ?? 3600) };
  return cachedToken.value;
}

// ------------------------------------------------------------
// Reading the message and who it is for.
// ------------------------------------------------------------
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function restGet(path: string): Promise<unknown[]> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
    },
  });
  if (!response.ok) {
    throw new Error(`reading ${path} gave ${response.status}: ${await response.text()}`);
  }
  return await response.json();
}

async function forgetToken(token: string): Promise<void> {
  await fetch(
    `${SUPABASE_URL}/rest/v1/device_tokens?token=eq.${encodeURIComponent(token)}`,
    {
      method: "DELETE",
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
      },
    },
  );
}

// ------------------------------------------------------------
// The send itself.
//
// One request per token, because FCM v1 has no multicast: the old
// registration_ids array belonged to the legacy API, which Google turned
// off. A customer with two handsets is two requests, which is fine at
// this shop's volume.
// ------------------------------------------------------------
interface Notification {
  notification_id: number;
  customer_id: number;
  order_id: number | null;
  product_id: number | null;
  kind: string;
  title: string;
  body: string;
}

async function sendTo(token: string, note: Notification, bearer: string, projectId: string) {
  const message = {
    message: {
      token,
      notification: { title: note.title, body: note.body },
      // Carried alongside the visible text so a tap can open the right
      // screen. Every value has to be a string -- FCM rejects a data
      // block with numbers in it, which is a cheerful half hour to lose.
      data: {
        kind: String(note.kind),
        notification_id: String(note.notification_id),
        order_id: note.order_id === null ? "" : String(note.order_id),
        product_id: note.product_id === null ? "" : String(note.product_id),
      },
      android: {
        priority: "high",
        notification: {
          channel_id: "etech_orders",
          // Groups a customer's messages under one heading in the tray
          // rather than stacking four separate cards.
          tag: note.order_id ? `order-${note.order_id}` : `note-${note.notification_id}`,
        },
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${bearer}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    },
  );

  if (response.ok) return;

  const text = await response.text();

  // A token Google no longer recognises belongs to an app that was
  // uninstalled or had its data cleared. Deleting it here is the only
  // tidying this table ever gets -- nothing else knows the token died.
  if (response.status === 404 || text.includes("UNREGISTERED") ||
      text.includes("INVALID_ARGUMENT")) {
    console.log(`push: dropping dead token (${response.status})`);
    await forgetToken(token);
    return;
  }

  console.error(`push: FCM said ${response.status}: ${text}`);
}

Deno.serve(async (request) => {
  // Always 200. See the note at the top about why a failure here is
  // quiet: the notification row is already written, and the bell will
  // show it whatever happens below.
  const ok = () => new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });

  try {
    const { notification_id } = await request.json();
    if (!notification_id) {
      console.error("push: called with no notification_id");
      return ok();
    }

    const rows = await restGet(
      `notifications?notification_id=eq.${Number(notification_id)}` +
      `&select=notification_id,customer_id,order_id,product_id,kind,title,body`,
    ) as Notification[];

    const note = rows[0];
    if (!note) {
      console.error(`push: notification ${notification_id} not found`);
      return ok();
    }

    const tokens = await restGet(
      `device_tokens?customer_id=eq.${note.customer_id}&select=token`,
    ) as { token: string }[];

    if (tokens.length === 0) {
      // Not an error and not rare. Plenty of customers use the website
      // only, and they have no handset registered to shout at.
      console.log(`push: customer ${note.customer_id} has no registered device`);
      return ok();
    }

    const account = serviceAccount();
    const bearer = await accessToken();

    await Promise.all(
      tokens.map((row) => sendTo(row.token, note, bearer, account.project_id)),
    );

    console.log(`push: notification ${note.notification_id} sent to ${tokens.length} device(s)`);
    return ok();
  } catch (error) {
    console.error("push: " + (error instanceof Error ? error.message : String(error)));
    return ok();
  }
});
