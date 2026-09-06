// ============================================================
// Product photos: check, shrink, flatten, send.
//
// This was written inside product_edit.js and lived there alone until
// the prebuilt page needed to put a poster on a rig. Two copies of an
// uploader is two places for the size limit to drift apart, so it moved
// out here instead. product_edit.js and prebuilts.js both load it; the
// behaviour is unchanged from the version that shipped in product_edit.
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
// answer is that they are not the security boundary. The bucket itself
// refuses anything over 5MB or of the wrong type, and refuses uploads
// from anyone who is not staff. What happens here is for the person
// using the page; what happens in the bucket is the rule.
// ============================================================

const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const MAX_PHOTO_SIDE = 800;
const PHOTO_QUALITY = 0.85;
const PHOTO_BUCKET = "product-images";

// What the file input should accept, and what checkPhoto() enforces.
const PHOTO_TYPES = ["image/jpeg", "image/png", "image/webp"];

// Reads a chosen file and returns a complaint, or null if it is fine.
// Both pages ask the same two questions, so they ask them here.
function checkPhoto(file) {
  if (!file) return null;
  if (file.size > MAX_PHOTO_BYTES) return "Photo must be under 5MB.";
  if (!PHOTO_TYPES.includes(file.type)) return "Photo must be a JPG, PNG or WEBP.";
  return null;
}

// ------------------------------------------------------------
// Reading the file into an <img> is also the check that it really is an
// image, in the same way getimagesize() was: a renamed .exe will not
// decode and the promise rejects. Drawing it onto a canvas and reading
// it back as JPEG is what strips anything hidden in the original file,
// which is why the PHP redrew rather than simply moving the upload.
// ------------------------------------------------------------
async function uploadPhoto(file, productId) {
  const image = await readImage(file);

  // Scale down so the shop stays quick to load. Never scales up.
  const scale = Math.min(MAX_PHOTO_SIDE / image.width, MAX_PHOTO_SIDE / image.height, 1);
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

  // The timestamp is what the PHP used too: a new name every time, so a
  // replaced photo is never served from a stale cache.
  const path = `p${productId}_${Date.now()}.jpg`;

  const { error } = await sb.storage.from(PHOTO_BUCKET)
    .upload(path, blob, { contentType: "image/jpeg", upsert: false });
  if (error) throw error;

  return sb.storage.from(PHOTO_BUCKET).getPublicUrl(path).data.publicUrl;
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
