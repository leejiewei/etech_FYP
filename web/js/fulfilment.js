// ============================================================
// Collection or delivery, and the words each one uses.
//
// An order goes through four stages in the database -- Pending,
// Processing, Ready, Collected -- and those four are the same four
// whichever way the customer is getting their things. What differs is
// what the last two are *called*:
//
//   stage        PICKUP             DELIVERY
//   Ready        Ready to collect   Shipped
//   Collected    Collected          Delivered
//
// Keeping one ladder and translating the rungs is deliberate. The
// alternative -- seven stages, three of them meaningless for any given
// order -- would give staff a dropdown full of wrong answers and would
// make every report that groups by status have to know that Ready and
// Shipped are the same thing. See
// supabase/migrations/20260916160000_collect_it_or_have_it_sent.sql.
//
// This file is the only place those words live. The customer's order
// history, the staff console and the checkout page all read them from
// here, so the shop cannot end up calling the same stage two things on
// two screens. mobile/lib/fulfilment.dart is the same table for the app.
// ============================================================

// What the method itself is called, when it has to be named on its own.
const FULFILMENT_LABELS = {
  PICKUP: "Collection",
  DELIVERY: "Delivery",
};

// The four stages in order. The progress strip walks this, so the order
// matters as much as the words.
const FULFILMENT_STAGES = ["Pending", "Processing", "Ready", "Collected"];

const STAGE_WORDS = {
  PICKUP: {
    Pending: "Pending",
    Processing: "Processing",
    Ready: "Ready to collect",
    Collected: "Collected",
    Cancelled: "Cancelled",
  },
  DELIVERY: {
    Pending: "Pending",
    Processing: "Processing",
    Ready: "Shipped",
    Collected: "Delivered",
    Cancelled: "Cancelled",
  },
};

// Falls back to PICKUP for a row whose method is missing rather than
// throwing: an order placed before the column existed is a collection as
// far as anything here is concerned, and a blank stage on screen helps
// nobody.
function stageLabel(status, method) {
  const words = STAGE_WORDS[method] || STAGE_WORDS.PICKUP;
  return words[status] || status;
}

// The same four labels, in order, for a progress strip.
function stageLabels(method) {
  return FULFILMENT_STAGES.map((s) => stageLabel(s, method));
}

function isDelivery(method) {
  return method === "DELIVERY";
}
