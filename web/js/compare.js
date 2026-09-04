// Compare list logic. Lets the user tick up to 3 products and view them
// side by side on compare.html.

const MAX_COMPARE = 3;

function getCompareList() {
  const text = localStorage.getItem("compare");
  if (text === null) return [];
  return JSON.parse(text);
}

function saveCompareList(list) {
  localStorage.setItem("compare", JSON.stringify(list));
}

function isInCompare(productId) {
  return getCompareList().includes(productId);
}

function toggleCompare(productId) {
  let list = getCompareList();

  if (list.includes(productId)) {
    list = list.filter((id) => id !== productId);
  } else {
    if (list.length >= MAX_COMPARE) {
      alert("You can only compare up to " + MAX_COMPARE + " products at a time. Remove one first.");
      // re-render so the checkbox flips back to unchecked
      if (typeof renderProductGrid === "function") renderProductGrid();
      return;
    }
    list.push(productId);
  }

  saveCompareList(list);
  updateCompareCount();

  if (typeof renderProductGrid === "function") renderProductGrid();
}

function updateCompareCount() {
  const el = document.getElementById("compare-count");
  if (el) el.textContent = getCompareList().length;
}

function renderComparePage() {
  const container = document.getElementById("compare-table-wrap");
  const emptyMessage = document.getElementById("compare-empty");
  if (!container) return;

  const list = getCompareList().map(getProductById).filter(Boolean);

  if (list.length === 0) {
    container.innerHTML = "";
    emptyMessage.style.display = "block";
    return;
  }

  emptyMessage.style.display = "none";

  // Collect every attribute key used by any of the compared products, so the
  // table has a row for each one (socket, ramGen, screenSize, etc).
  const attrKeys = [];
  list.forEach((p) => {
    Object.keys(p.attrs || {}).forEach((key) => {
      if (!attrKeys.includes(key)) attrKeys.push(key);
    });
  });

  let html = '<table class="compare-table"><thead><tr><th></th>';
  list.forEach((p) => {
    html += `<th>
      <img class="compare-img" src="${safeUrl(productImage(p))}" alt="${escapeHtml(p.name)}"
        onerror="this.onerror=null; this.src='${safeUrl(productImageFallback(p))}';" />
      <div>${escapeHtml(p.name)}</div>
      <button class="remove-btn" onclick="toggleCompare(${p.id}); renderComparePage();">Remove</button>
    </th>`;
  });
  html += "</tr></thead><tbody>";

  html += "<tr><td>Brand</td>" + list.map((p) => `<td>${escapeHtml(p.brand)}</td>`).join("") + "</tr>";
  html += "<tr><td>Price</td>" + list.map((p) => `<td>RM ${p.price.toFixed(2)}</td>`).join("") + "</tr>";
  html += "<tr><td>Stock</td>" + list.map((p) => `<td>${stockLabel(p.stock)}</td>`).join("") + "</tr>";

  attrKeys.forEach((key) => {
    html += `<tr><td>${escapeHtml(attrLabel(key))}</td>` + list.map((p) => `<td>${escapeHtml((p.attrs && p.attrs[key]) || "-")}</td>`).join("") + "</tr>";
  });

  html += "</tbody></table>";
  container.innerHTML = html;
}

onAppReady(updateCompareCount);
