// ============================================================
// Photographs: check, shrink, flatten, send.
//
// This was written inside product_edit.js and lived there alone until
// the prebuilt page needed to put a poster on a rig. Two copies of an
// uploader is two places for the size limit to drift apart, so it moved
// out into the admin console's own folder, and now out of there too:
// the shop front needs it as well, so a customer can photograph a bank
// transfer receipt at the checkout.
//
// That move is why the bucket is an argument now rather than a constant.
// It is also why the caller says whether the result is a public URL or a
// path: a product photo is served to the world, and a receipt is served
// to the customer who sent it and to staff, through a link signed at the
// moment somebody looks. Storing a signed URL would be storing something
// that expires, so for a private bucket what comes back -- and what goes
// into the database -- is the path.
//
// The history is worth keeping: product_edit.php took the upload,
// checked it was really an image, resized it with GD and wrote a JPEG
// into web/uploads/. That only worked because there was a PHP process
// with a filesystem behind it, and there isn't one now. So the same
// three steps happen in the browser — check, resize, convert — using a
// canvas, and the result goes to Supabase Storage. Doing the resize here
// is not merely a substitute: a 4MB phone photo becomes an 80KB JPEG
// before it is sent rather than after.
//
// The checks being in the browser raises the obvious question, and the
// answer is that they are not the security boundary. Each bucket refuses
// anything over 5MB or of the wrong type on its own, and its policies
// decide who may write to it at all -- staff for product photos, and for
// receipts only the customer whose own folder is being written to. What
// happens here is for the person using the page; what happens in the
// bucket is the rule.
// ============================================================

const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const MAX_PHOTO_QUALITY_SIDE = 800;
const PHOTO_QUALITY = 0.85;

// A receipt is read rather than glanced at -- an account number and an
// amount have to stay legible -- and somebody's build is looked at
// properly rather than skimmed in a grid. Both keep more pixels than a
// product thumbnail needs.
const MAX_LARGE_SIDE = 1600;

// What the file input should accept, and what checkPhoto() enforces.
const PHOTO_TYPES = ["image/jpeg", "image/png", "image/webp"];

// The same two rules, said to the customer next to the receipt picker --
// before they choose a file, not only in an error after they have. Built
// from the limits above so the sentence cannot drift from what is checked.
const PHOTO_LIMIT_MB = MAX_PHOTO_BYTES / (1024 * 1024);
const PHOTO_LIMITS_TEXT = `JPG, PNG or WEBP, up to ${PHOTO_LIMIT_MB}MB.`;

// Reads a chosen file and returns a complaint, or null if it is fine.
// Both pages ask the same two questions, so they ask them here. The size
// complaint says how big the file was: "must be under 5MB" alone leaves
// somebody guessing whether their photo was 5.1MB or 40MB.
function checkPhoto(file) {
  if (!file) return null;
  if (file.size > MAX_PHOTO_BYTES) {
    const mb = (file.size / (1024 * 1024)).toFixed(1);
    return `That photo is ${mb}MB. The limit is ${PHOTO_LIMIT_MB}MB.`;
  }
  if (!PHOTO_TYPES.includes(file.type)) return "That file is not a JPG, PNG or WEBP photo.";
  return null;
}

// ------------------------------------------------------------
// Reading the file into an <img> is also the check that it really is an
// image, in the same way getimagesize() was: a renamed .exe will not
// decode and the promise rejects. Drawing it onto a canvas and reading
// it back as JPEG is what strips anything hidden in the original file,
// which is why the PHP redrew rather than simply moving the upload.
// ------------------------------------------------------------
// Shrinks the file, converts it to JPEG and puts it in [bucket] at
// [path]. Returns the public URL for a public bucket, or the path it was
// stored at for a private one.
async function sendPhoto(file, { bucket, path, maxSide, isPublic }) {
  const image = await readImage(file);

  // Scale down so the shop stays quick to load. Never scales up.
  const scale = Math.min(maxSide / image.width, maxSide / image.height, 1);
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(image.width * scale);
  canvas.height = Math.round(image.height * scale);

  const context = canvas.getContext("2d");
  context.fillStyle = "#ffffff";                 // flatten transparency
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.drawImage(image, 0, 0, canvas.width, canvas.height);

  const blob = await new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("Could not convert that image."))),
                  "image/jpeg", PHOTO_QUALITY));

  const { error } = await sb.storage.from(bucket)
    .upload(path, blob, { contentType: "image/jpeg", upsert: false });
  if (error) throw error;

  return isPublic ? sb.storage.from(bucket).getPublicUrl(path).data.publicUrl : path;
}

// A product photo or a rig poster. Public, and named with a timestamp
// exactly as the PHP did: a new name every time, so a replaced photo is
// never served from a stale cache.
function uploadPhoto(file, productId) {
  return sendPhoto(file, {
    bucket: "product-images",
    path: `p${productId}_${Date.now()}.jpg`,
    maxSide: MAX_PHOTO_QUALITY_SIDE,
    isPublic: true,
  });
}

// A photograph of somebody's build for the showcase gallery. Public,
// like a product photo, and filed under the customer's own folder
// because that folder name is what the bucket's policy checks before
// allowing the write.
//
// A random suffix as well as the timestamp: six photos submitted in the
// same millisecond would otherwise collide, and upsert is off precisely
// so that a collision is an error rather than a silent overwrite of
// somebody else's picture.
function uploadRigPhoto(file, customerId) {
  const stamp = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  return sendPhoto(file, {
    bucket: "rig-showcases",
    path: `${customerId}/rig_${stamp}.jpg`,
    maxSide: MAX_LARGE_SIDE,
    isPublic: true,
  });
}

// A payment receipt. Private, and filed under a folder named after the
// customer, because that folder name is what the bucket's policies check
// before allowing the write -- and what stops one customer reading
// another's. [customerId] is read from the signed-in profile rather than
// typed anywhere; the database checks it again in
// attach_payment_receipt() before the path is recorded against an order.
function uploadReceipt(file, customerId, orderId) {
  return sendPhoto(file, {
    bucket: "payment-receipts",
    path: `${customerId}/order${orderId}_${Date.now()}.jpg`,
    maxSide: MAX_LARGE_SIDE,
    isPublic: false,
  });
}

function readImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => { URL.revokeObjectURL(url); resolve(image); };
    image.onerror = () => { URL.revokeObjectURL(url); reject(new Error("That file is not an image.")); };
    image.src = url;
  });
}
