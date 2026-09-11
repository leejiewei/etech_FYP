// ============================================================
// Messages from the shop about the customer's own orders.
//
// Staff approving a payment, rejecting a receipt or marking an order
// Shipped leaves a row in the notifications table -- the database does
// that inside the same function that moves the order, so there is no
// version of events where the order moved and the customer was not told.
// See supabase/migrations/20260911090000_order_notifications.sql.
//
// This file shows those rows in two ways:
//
//   * the bell in the navbar, with a count of the unread ones and a
//     list that opens under it. Opening the list is what marks them read.
//   * a toast, for a message that arrives while a page is open. Realtime
//     pushes the new row the moment staff press the button, so a customer
//     sitting on Order History sees it without reloading.
//
// Every page that has the navbar loads this file. With nobody signed in
// it does nothing at all -- there is no bell to draw and nothing to hear.
// ============================================================

const NOTIFICATION_LIMIT = 20;

let notifications = [];
let notificationChannel = null;

// Newest first, the last twenty. The policy on the table returns the
// signed-in customer's rows and nobody else's, so there is no "mine"
// filter here to get wrong.
function loadNotifications() {
  return sb.from("notifications")
    .select("notification_id,order_id,kind,title,body,created_at,read_at")
    .order("created_at", { ascending: false })
    .limit(NOTIFICATION_LIMIT)
    .then(({ data, error }) => {
      if (error) { console.error("Loading notifications:", error); return; }
      notifications = data;
      renderNotifications();
    });
}

function unreadNotificationCount() {
  return notifications.filter((n) => !n.read_at).length;
}

function renderNotifications() {
  const count = document.getElementById("notif-count");
  const list = document.getElementById("notif-list");
  if (!count || !list) return;

  const unread = unreadNotificationCount();
  count.textContent = unread > 9 ? "9+" : String(unread);
  count.hidden = unread === 0;

  list.innerHTML = notifications.length === 0
    ? `<p class="notif-empty">Nothing yet. We will let you know here when your order moves.</p>`
    : notifications.map(notificationItem).join("");
}

function notificationItem(n) {
  const href = n.order_id ? `orders.html#order-${n.order_id}` : "orders.html";
  return `
    <a class="notif-item ${n.read_at ? "" : "unread"} notif-${escapeHtml(n.kind)}" href="${href}">
      <strong>${escapeHtml(n.title)}</strong>
      <span>${escapeHtml(n.body)}</span>
      <small>${escapeHtml(timeAgo(n.created_at))}</small>
    </a>`;
}

function timeAgo(iso) {
  const seconds = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  if (seconds < 60) return "Just now";
  if (seconds < 3600) return `${Math.floor(seconds / 60)} min ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)} h ago`;
  return new Date(iso).toLocaleDateString();
}

// Opening the list is reading it. The rows are marked in the database
// straight away, but keep their highlight on screen until the list is
// closed -- clearing them as the customer looks at them would make the
// new ones impossible to pick out.
function toggleNotificationPanel(open) {
  const panel = document.getElementById("notif-panel");
  const bell = document.getElementById("notif-bell");
  if (!panel || !bell) return;

  const willOpen = open === undefined ? panel.hidden : open;
  if (willOpen === !panel.hidden) return;

  panel.hidden = !willOpen;
  bell.setAttribute("aria-expanded", String(willOpen));

  if (willOpen && unreadNotificationCount() > 0) {
    sb.rpc("mark_notifications_read").then(({ error }) => {
      if (error) { console.error("Marking notifications read:", error); return; }
      const now = new Date().toISOString();
      notifications.forEach((n) => { n.read_at ||= now; });
      const count = document.getElementById("notif-count");
      if (count) count.hidden = true;
    });
  }
  if (!willOpen) renderNotifications();
}

// A message that arrived while the page was open.
function receiveNotification(row) {
  if (notifications.some((n) => n.notification_id === row.notification_id)) return;
  notifications.unshift(row);
  notifications = notifications.slice(0, NOTIFICATION_LIMIT);
  renderNotifications();
  showNotificationToast(row);

  // Order History listens for this and redraws, so the badge on the card
  // changes at the same moment the toast appears.
  document.dispatchEvent(new CustomEvent("etech:notification", { detail: row }));
}

function showNotificationToast(n) {
  const toast = document.createElement("div");
  toast.className = "toast notif-toast";
  const href = n.order_id ? `orders.html#order-${n.order_id}` : "orders.html";
  toast.innerHTML = `🔔 <strong>${escapeHtml(n.title)}</strong> ${escapeHtml(n.body)}
    <a href="${href}">View order</a>`;
  document.body.appendChild(toast);

  setTimeout(() => toast.classList.add("show"), 100);
  setTimeout(() => toast.remove(), 9000);
}

// Realtime applies the same "own notifications" policy before handing a
// row over, so the filter below is not what keeps other customers' news
// out -- it only saves the server checking rows that were never ours.
function subscribeToNotifications(customerId) {
  if (notificationChannel) return;
  notificationChannel = sb.channel(`notifications-${customerId}`)
    .on("postgres_changes",
        { event: "INSERT", schema: "public", table: "notifications",
          filter: `customer_id=eq.${customerId}` },
        (payload) => receiveNotification(payload.new))
    .subscribe();
}

function startNotifications() {
  const user = getCurrentUser();
  if (!user) return;

  const bell = document.getElementById("notif-bell");
  if (bell) {
    bell.addEventListener("click", (e) => {
      e.stopPropagation();
      toggleNotificationPanel();
    });
    document.addEventListener("click", (e) => {
      if (e.target.closest && e.target.closest("#notif-menu")) return;
      toggleNotificationPanel(false);
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") toggleNotificationPanel(false);
    });
  }

  loadNotifications();
  subscribeToNotifications(user.id);
}

onAppReady(startNotifications);
