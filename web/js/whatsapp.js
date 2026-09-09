// ============================================================
// Reaching somebody on WhatsApp.
//
// The shop already had a floating chat button pointing at its own
// number. Manual payment verification gave it two more places to go:
// a customer telling the shop they have paid, and staff telling a
// customer whether that payment was accepted. Both are the same
// mechanism, so the number and the rules for writing one live here
// rather than three times over.
//
// WHY THIS IS wa.me AND NOT THE WHATSAPP API
//
// A `wa.me` link opens WhatsApp with the recipient and the message
// already filled in, and a person presses send. Sending a message
// *automatically* is a different product -- the WhatsApp Business Cloud
// API -- and it needs a verified Meta business account, a message
// template approved in advance by Meta, a server-side token, and a
// per-conversation fee. That is days of somebody else's approval
// process, and the beta is not waiting for it.
//
// The trade is honest and worth writing down: nothing here sends
// anything. It composes a message and hands it to a human. Staff still
// have to press send, and the shop must not treat "the button was
// clicked" as "the customer was told".
//
// This file is loaded by the shop front and by the staff console, which
// is why it sits in web/js/ rather than under staff-console/ -- the same
// move photo.js made when the shop needed the uploader too.
// ============================================================

// Our number, in the form wa.me wants: international, no "+", no dashes,
// no leading zero. 011-1074 3634 becomes 601110743634 (60 = Malaysia,
// then 11 10743634).
const WHATSAPP_NUMBER = "601110743634";

// ------------------------------------------------------------
// A phone number as somebody typed it, turned into the form wa.me wants.
//
// The number in `orders.shipping_phone` was typed into a form by a
// customer, so it arrives however they felt like writing it:
// "011-1074 3634", "0111074 3634", "+60 11 1074 3634". wa.me accepts
// exactly one of those shapes and silently opens a chat with nobody if
// given any of the others.
//
// Returns "" when there is nothing usable, and every caller checks --
// a WhatsApp button that opens an empty chat is worse than no button,
// because staff would believe they had messaged somebody.
// ------------------------------------------------------------
function whatsappNumber(raw) {
  const typed = String(raw || "").trim();
  if (typed === "") return "";

  const digits = typed.replace(/\D/g, "");
  // Too short to be a phone number at all. Usually an empty field that
  // picked up a stray character, or somebody typing "-".
  if (digits.length < 8) return "";

  // Written with a country code already, either as +60… or as 60…:
  // believe it, including for the occasional non-Malaysian number.
  if (typed.startsWith("+") || digits.startsWith("60")) return digits;

  // The ordinary Malaysian way of writing it. The leading zero is a
  // domestic dialling prefix and is not part of the international number.
  if (digits.startsWith("0")) return "60" + digits.slice(1);

  // Written without either, which people do when they have already
  // dropped the zero themselves.
  return "60" + digits;
}

// A link that opens WhatsApp with the message ready to send. Returns ""
// if the number is unusable, so callers can decide not to draw a button
// at all rather than drawing one that goes nowhere.
function whatsappLink(number, message) {
  const to = whatsappNumber(number);
  if (to === "") return "";
  return "https://wa.me/" + to + "?text=" + encodeURIComponent(message || "");
}

// The shop's own chat, for a customer who wants to talk to us.
function whatsappShopLink(message) {
  return whatsappLink(WHATSAPP_NUMBER, message);
}

// Just the given name. "Ahmad bin Hassan" becomes "Ahmad", because a
// message opening with somebody's full legal name reads like a summons.
// Falls back to a greeting with no name rather than an empty gap.
function firstName(fullName) {
  const first = String(fullName || "").trim().split(/\s+/)[0];
  return first || "there";
}

// ------------------------------------------------------------
// What the shop says to a customer about their payment.
//
// Written out in full here, rather than assembled from fragments at the
// call site, because these are the shop's words to a customer and
// somebody should be able to read them without reading the code around
// them. Staff can edit the text in WhatsApp before sending; this is a
// starting point, not a script they are locked into.
// ------------------------------------------------------------
function paymentMessage(order) {
  const hello = "Hi " + firstName(order.shipping_name) +
                ", this is eTech Computer Accessories about order #" +
                order.order_id + ".";

  if (order.payment_status === "APPROVED") {
    return hello + " We have checked your payment and it is confirmed. " +
           "We are getting your order ready now and will let you know as " +
           "soon as it is on its way. Thank you!";
  }

  if (order.payment_status === "REJECTED") {
    return hello + " We were not able to confirm your payment from the " +
           "receipt you sent. Could you check it and send us another one? " +
           "If you think this is a mistake, just reply here and we will " +
           "look again.";
  }

  // PENDING, which covers two different situations: a receipt is waiting
  // to be checked, or none has arrived. The second is the one staff
  // actually need to chase, so the message asks for it.
  if (!order.receipt_image_path) {
    return hello + " We have not received your payment receipt yet. " +
           "When you have paid, could you send us a photo or screenshot " +
           "of the transfer here? We will check it and get your order moving.";
  }

  return hello + " We have your receipt and are checking it now. " +
         "We will confirm as soon as it is done.";
}
