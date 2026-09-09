// ============================================================
// How the shop takes money.
//
// There is no payment gateway. A student project has no merchant
// account, and the shop this is modelled on does what most small
// Malaysian retailers do: shows a DuitNow QR or a bank account, lets the
// customer pay from their own banking app, and has somebody look at the
// receipt before anything is packed.
//
// So the details are here, in one file, rather than typed into the
// checkout page and again into the order history page and again into the
// app. They are shop facts, not page furniture.
//
// ------------------------------------------------------------
// THE BANK ACCOUNT IS REAL. THE DUITNOW ID IS NOT, YET.
//
// The transfer details below are the shop's actual Maybank account, so
// money sent to them arrives. The DuitNow entry is still a placeholder
// and is written to be unmistakable rather than plausible, for the
// reason the whole file was written that way: a realistic looking
// identifier in a demo is the kind of thing that gets screenshotted,
// quoted in a report, or paid into by somebody who did not read the
// surrounding page.
//
// Because one method works and the other does not, the shop must not
// offer both as though they were equal. duitNowReady() below is what
// decides that, and it is the only thing that needs to change: fill in
// duitNowId, drop the image into web/images/duitnow-qr.png, and the QR
// option turns itself back on everywhere it appears.
// ------------------------------------------------------------
// ============================================================

const DUITNOW_PLACEHOLDER = "PLACEHOLDER — set this in js/payment.js";

const PAYMENT_DETAILS = {
  bankName:      "Maybank",
  accountName:   "eTech Computer",
  accountNumber: "557139242697",
  duitNowId:     DUITNOW_PLACEHOLDER,
  qrImage:       "images/duitnow-qr.png",
};

// Whether DuitNow can actually be paid. Everything that offers, defaults
// to, or explains a payment method asks this rather than deciding for
// itself, so there is one answer and it changes in one place.
//
// mobile/lib/payment_details.dart carries the same check against the same
// values. The two must agree: two clients disagreeing about which methods
// the shop accepts is worse than either being wrong.
function duitNowReady() {
  const id = PAYMENT_DETAILS.duitNowId;
  return typeof id === "string" && id.trim() !== "" && id !== DUITNOW_PLACEHOLDER;
}

const PAYMENT_METHOD_LABELS = {
  QR_CODE:       "DuitNow QR",
  BANK_TRANSFER: "Bank transfer",
};

const PAYMENT_STATUS_LABELS = {
  PENDING:  "Checking your payment",
  APPROVED: "Payment confirmed",
  REJECTED: "Payment needs another look",
};

// The block of instructions for one method. Used on the checkout form
// before the order is placed, and again on the confirmation and in the
// order history, so somebody who closed the tab can still find out where
// to send the money.
function paymentPanelHtml(method) {
  if (method === "QR_CODE") {
    // Shown where a past order recorded QR_CODE, or if the option is
    // reached before the details exist. Says what the customer should do
    // instead; the missing-image instruction below is for us and only
    // ever appears once the ID is set and the file is genuinely absent.
    if (!duitNowReady()) {
      return `
        <p><strong>DuitNow QR is not available yet</strong></p>
        <p class="form-note">Please pay by bank transfer instead, or contact us
        and we will send you the details.</p>`;
    }
    return `
      <p><strong>Scan to pay</strong></p>
      <img class="pay-qr" src="${safeUrl(PAYMENT_DETAILS.qrImage)}"
           alt="DuitNow QR code for eTech Computer Accessories"
           onerror="this.onerror=null; this.replaceWith(Object.assign(document.createElement('p'), {className:'pay-qr-missing', textContent:'QR image not uploaded yet — put it at ${PAYMENT_DETAILS.qrImage}'}));" />
      <p class="pay-line">DuitNow ID: <strong>${escapeHtml(PAYMENT_DETAILS.duitNowId)}</strong></p>
      <p class="form-note">Pay the exact amount shown, then send us the receipt.</p>`;
  }

  return `
    <p><strong>Transfer to</strong></p>
    <p class="pay-line">Bank: <strong>${escapeHtml(PAYMENT_DETAILS.bankName)}</strong></p>
    <p class="pay-line">Account name: <strong>${escapeHtml(PAYMENT_DETAILS.accountName)}</strong></p>
    <p class="pay-line">Account number: <strong>${escapeHtml(PAYMENT_DETAILS.accountNumber)}</strong></p>
    <p class="form-note">Pay the exact amount shown, then send us the receipt.</p>`;
}

// The chosen radio on the checkout form.
function chosenPaymentMethod() {
  const picked = document.querySelector("input[name='payment-method']:checked");
  if (picked) return picked.value;
  // Falling back to a method nobody can pay would turn a stray click into
  // an order with nowhere to send the money.
  return duitNowReady() ? "QR_CODE" : "BANK_TRANSFER";
}

// ------------------------------------------------------------
// Take the DuitNow option away while it cannot be paid.
//
// Called by the checkout page once the form is on screen. The radio is
// disabled rather than removed so that the shop visibly accepts DuitNow
// normally and is visibly between QR codes right now, which is the true
// statement; and bank transfer is selected in its place, because the
// markup ships with DuitNow checked and an unattended default is exactly
// how somebody ends up on the method that does not work.
// ------------------------------------------------------------
function applyPaymentAvailability() {
  if (duitNowReady()) return;

  const qr   = document.querySelector("input[name='payment-method'][value='QR_CODE']");
  const bank = document.querySelector("input[name='payment-method'][value='BANK_TRANSFER']");
  if (!qr || !bank) return;

  qr.disabled = true;
  qr.checked  = false;
  const label = qr.closest(".pay-option");
  if (label) {
    label.classList.add("pay-option-off");
    const small = label.querySelector("small");
    if (small) small.textContent = "Unavailable at the moment";
  }

  bank.checked = true;
  showPaymentPanel("BANK_TRANSFER");
}

// Fills both panels once and shows the one that was picked. They are
// built rather than written into the HTML so the account details exist
// in one place.
function showPaymentPanel(method) {
  ["QR_CODE", "BANK_TRANSFER"].forEach((name) => {
    const panel = document.getElementById("pay-panel-" + name);
    if (!panel) return;
    if (panel.innerHTML.trim() === "") panel.innerHTML = paymentPanelHtml(name);
    panel.style.display = name === method ? "block" : "none";
  });
}
