// ============================================================
// Where the order is collected.
//
// Most orders are paid for online, put aside behind the counter, and
// picked up by the person who placed it. (Delivery is the other option —
// see js/fulfilment.js.) So the one thing every screen showing a
// collection has to be able to say is where that counter is and when
// somebody is standing at it.
//
// Those are shop facts, not page furniture, so they live here once
// rather than being typed into the checkout page and again into the
// order history page and again into the app. js/payment.js is written
// the same way and for the same reason.
//
// mobile/lib/pickup_details.dart carries the same values. The two must
// agree: two clients sending customers to different addresses is worse
// than either being wrong.
//
// ------------------------------------------------------------
// THE ADDRESS BELOW IS THE REAL SHOP.
//
// Unlike the DuitNow ID in payment.js, this one is filled in: it is the
// unit in Kompleks Bukit Jambul, and somebody who reads it off the
// checkout page and drives there on a Saturday will arrive at the right
// door. Treat it accordingly -- it is the shop's actual address, not
// demo furniture, and mobile/lib/pickup_details.dart carries the same
// two strings character for character.
//
// pickupReady() still guards every use of it. Blank the address out and
// every screen falls back to promising a message instead of naming a
// street, which is what should happen if the shop ever moves and nobody
// has the new unit number yet.
// ------------------------------------------------------------
// ============================================================

const PICKUP_PLACEHOLDER = "PLACEHOLDER — set this in js/pickup.js";

const PICKUP_DETAILS = {
  shopName: "eTech Computer",
  address:  "3A-4-164 & 165, Kompleks Bukit Jambul, Jalan Rumbia, Bukit Jambul, 11900 Bayan Lepas, Pulau Pinang",
  // Monday to Sunday, confirmed by the owner. "daily" rather than a
  // list of days because the notice prints it straight after "Open".
  hours:    "daily, 11am - 8pm",
  // Shown next to the address when there is one. A landmark saves more
  // phone calls than a postcode does -- and here the mall is the landmark,
  // so it is already in the address above and this stays empty.
  landmark: "",
};

// Whether the shop can actually be found. Everything that prints an
// address asks this rather than deciding for itself, so there is one
// answer and it changes in one place.
function pickupReady() {
  const a = PICKUP_DETAILS.address;
  return typeof a === "string" && a.trim() !== "" && a !== PICKUP_PLACEHOLDER;
}

// The collection notice, as one block of HTML.
//
// Two versions, and the difference is not cosmetic. With an address it
// tells somebody where to go; without one it promises a message, which
// is a thing the shop can actually keep. It never invents a street.
function pickupNoticeHtml() {
  if (!pickupReady()) {
    return `
      <div class="pickup-note">
        <strong>Collection at the shop</strong>
        <p>
          Your order is put aside for you and we will message the phone
          number above with the address and the pickup time as soon as it
          is ready.
        </p>
      </div>`;
  }

  return `
    <div class="pickup-note">
      <strong>Collection at the shop</strong>
      <p>
        Collect your order from
        <strong>${escapeHtml(PICKUP_DETAILS.shopName)}</strong>,
        ${escapeHtml(PICKUP_DETAILS.address)}${PICKUP_DETAILS.landmark
          ? " (" + escapeHtml(PICKUP_DETAILS.landmark) + ")" : ""}.
      </p>
      <p class="pickup-hours">
        Open ${escapeHtml(PICKUP_DETAILS.hours)} &middot;
        <a href="${pickupMapsUrl()}" target="_blank" rel="noopener">Open in Google Maps</a>
      </p>
      <p>We will message you when it is ready — please do not come before.</p>
    </div>`;
}

// One line, for the order card, where a whole notice would not fit.
function pickupLineText() {
  return pickupReady()
    ? "Collect at " + PICKUP_DETAILS.shopName + ", " + PICKUP_DETAILS.address
    : "Collect at the shop — we will message you the address when it is ready";
}

// A search for the address rather than a pinned coordinate, because a
// unit number inside a mall is something Maps resolves better from the
// written address than from a latitude somebody typed in once.
function pickupMapsUrl() {
  return "https://www.google.com/maps/search/?api=1&query=" +
    encodeURIComponent(PICKUP_DETAILS.shopName + ", " + PICKUP_DETAILS.address);
}

// The shop's own details, for the contact page.
//
// Built from the same two strings as the checkout notice rather than
// typed into contact.html, because an address that lives in two places
// is an address that will disagree with itself the first time the shop
// moves.
function shopAddressHtml() {
  if (!pickupReady()) return "";

  return `
    <div class="pickup-note">
      <strong>Where to find us</strong>
      <p>
        ${escapeHtml(PICKUP_DETAILS.shopName)}<br />
        ${escapeHtml(PICKUP_DETAILS.address)}
      </p>
      <p class="pickup-hours">Open ${escapeHtml(PICKUP_DETAILS.hours)}</p>
      <p>
        <a href="${pickupMapsUrl()}" target="_blank" rel="noopener">Open in Google Maps</a>
      </p>
      <p>
        Orders placed on this site can be collected here, or delivered to
        you if you would rather — you choose at checkout. Either way we
        message you when yours is on the move.
      </p>
    </div>`;
}

// Filled in wherever a page has asked for it by putting the element on
// the page. Listening for DOMContentLoaded rather than going through
// onAppReady, because this needs no session, no catalogue and no network
// -- it is two strings from the top of this file.
document.addEventListener("DOMContentLoaded", () => {
  const slot = document.getElementById("shop-address");
  if (!slot) return;

  // Hidden rather than left as an empty card if there is no address to
  // put in it. The slot carries the page's own card styling, so an empty
  // one would be a blank white box with nothing to explain it.
  const html = shopAddressHtml();
  slot.innerHTML = html;
  slot.style.display = html ? "" : "none";
});
