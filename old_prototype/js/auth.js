// Mock account system.
//
// IMPORTANT (for the viva): this is a plain frontend demo with NO server, so
// there is nowhere safe to store real passwords. We are NOT doing real
// encryption here — we just run the password through a simple scrambling
// function (btoa) so it is not sitting in localStorage as plain readable
// text. This is only good enough for a demo / prototype. A real system
// would send the password over HTTPS to a backend and hash it there
// (e.g. bcrypt), never store or "encrypt" it in the browser.

function fakeHash(text) {
  return btoa(unescape(encodeURIComponent(text)));
}

function getUsers() {
  const usersText = localStorage.getItem("users");
  if (usersText === null) return [];
  return JSON.parse(usersText);
}

function saveUsers(users) {
  localStorage.setItem("users", JSON.stringify(users));
}

function getCurrentUser() {
  const email = localStorage.getItem("sessionEmail");
  if (!email) return null;
  const users = getUsers();
  return users.find((u) => u.email === email) || null;
}

function isLoggedIn() {
  return getCurrentUser() !== null;
}

// Returns "" on success, or an error message string on failure.
function registerUser(name, email, password) {
  const users = getUsers();

  if (users.some((u) => u.email === email)) {
    return "An account with this email already exists.";
  }

  users.push({
    name: name,
    email: email,
    passwordHash: fakeHash(password),
    address: "",
    phone: "",
    orders: [],
  });

  saveUsers(users);
  localStorage.setItem("sessionEmail", email); // auto login after register
  return "";
}

// Returns "" on success, or an error message string on failure.
function loginUser(email, password) {
  const users = getUsers();
  const user = users.find((u) => u.email === email);

  if (!user || user.passwordHash !== fakeHash(password)) {
    return "Incorrect email or password.";
  }

  localStorage.setItem("sessionEmail", email);
  return "";
}

function logoutUser() {
  localStorage.removeItem("sessionEmail");
  window.location.href = "index.html";
}

// Updates the logged-in user's profile fields (name, address, phone) and saves it.
function updateProfile(fields) {
  const user = getCurrentUser();
  if (!user) return;

  const users = getUsers();
  const index = users.findIndex((u) => u.email === user.email);
  users[index] = Object.assign(users[index], fields);
  saveUsers(users);
}

// Adds an order to the logged-in user's order history.
function addOrderToHistory(order) {
  const user = getCurrentUser();
  if (!user) return;

  const users = getUsers();
  const index = users.findIndex((u) => u.email === user.email);
  users[index].orders.push(order);
  saveUsers(users);
}
