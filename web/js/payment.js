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
// THESE ARE PLACEHOLDERS AND MUST BE REPLACED BEFORE THE SHOP TAKES A
// REAL PAYMENT.
//
// They are deliberately obvious rather than plausible. A realistic
// looking account number in a demo is the kind of thing that gets
// screenshotted, quoted in a report, or paid into by somebody who did
// not read the surrounding page -- so the fake is written to be
// unmistakable. Put the real ones here, drop the QR image into
// web/images/duitnow-qr.png, and delete this notice.
// ------------------------------------------------------------
// ============================================================

const PAYMENT_DETAILS = {
  bankName:      "PLACEHOLDER BANK — NOT A REAL ACCOUNT",
  accountName:   "eTech Computer Accessories (PLACEHOLDER)",
  accountNumber: "0000-0000-0000",
  duitNowId:     "PLACEHOLDER — set this in js/payment.js",
  qrImage:       "images/duitnow-qr.png",
};

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
  return picked ? picked.value : "QR_CODE";
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
