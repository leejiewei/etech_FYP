// ============================================================
// Customer accounts.
//
// Accounts started life in localStorage with a scrambled password,
// which was only ever a stand-in. They then moved to the customers
// table, with PHP hashing the password and a PHP session deciding who
// was signed in. This is the third and last move: Supabase Auth holds
// the password and issues the session, and the browser talks to it
// directly.
//
// What that changes, and why it had to change:
//
//   * Being signed in used to be a PHPSESSID cookie pointing at a file
//     on the server. It is now a signed token (a JWT) held by this
//     browser and sent with every database request.
//
//   * That token is the only thing Row Level Security can read. Without
//     it, "show me my orders" has no way to mean anything to Postgres —
//     which is precisely why the accounts had to move before the rest
//     of the site could stop going through PHP.
//
//   * The passwords themselves did not change. They were bcrypt hashes
//     from PHP's password_hash(), and Supabase Auth reads bcrypt, so
//     they were copied across as they were. Nobody had to reset
//     anything. See supabase/migrations/…_migrate_accounts.sql.
//
// The customers table is still where a customer's name, phone and
// address live. Supabase Auth only holds the login; the row in
// customers is the profile, and the two are joined by auth_user_id.
// ============================================================

let currentUser = null;      // filled in by loadSession()

// The columns a customer is allowed to read of their own row. Asking
// for * would fail: the password_hash column is revoked from every
// client role, and a SELECT * has to be allowed every column it lands on.
const PROFILE_COLUMNS = "customer_id,name,email,phone,address";

// ------------------------------------------------------------
// Who is signed in?
//
// Called once when a page loads, from app.js. Two steps rather than
// one: Supabase says whether there is a valid session, and the
// customers table says who that session belongs to. The policy on that
// table means the query can only ever return the caller's own row.
// ------------------------------------------------------------
function loadSession() {
  return sb.auth.getSession()
    .then(({ data }) => {
      if (!data.session) { currentUser = null; return null; }
      return sb.from("customers").select(PROFILE_COLUMNS).maybeSingle()
        .then(({ data: row, error }) => {
          if (error || !row) {
            // A valid login with no customers row is a staff account, or
            // one whose row was removed. Either way this is not a shopper.
            currentUser = null;
            return null;
          }
          currentUser = shapeCustomer(row);
          return currentUser;
        });
    })
    .catch(() => { currentUser = null; return null; });
}

// The site has always called the customer's id `id`. Keeping that means
// nothing outside this file has to know the column is customer_id.
function shapeCustomer(row) {
  return {
    id:      row.customer_id,
    name:    row.name,
    email:   row.email,
    phone:   row.phone,
    address: row.address,
  };
}

function getCurrentUser() {
  return currentUser;
}

function isLoggedIn() {
  return currentUser !== null;
}

// ------------------------------------------------------------
// Registering.
//
// signUp writes to Supabase Auth. The customers row is made by a
// database trigger watching for new auth users, which is why the name
// is passed as sign-up metadata — the trigger reads it from there.
//
// Returns "" when it worked, or a message to show the customer.
// ------------------------------------------------------------
function registerUser(name, email, password) {
  name = (name || "").trim();
  email = (email || "").trim().toLowerCase();

  // The same three checks the PHP made, kept here so the wording the
  // customer sees does not change. Supabase enforces its own versions
  // as well; these just get in first with a friendlier sentence.
  if (name === "" || email === "" || !password) {
    return Promise.resolve("Please fill in every field.");
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return Promise.resolve("That email address does not look right.");
  }
  if (password.length < 6) {
    return Promise.resolve("Password must be at least 6 characters.");
  }

  return sb.auth.signUp({ email, password, options: { data: { name } } })
    .then(({ data, error }) => {
      if (error) return registerError(error);

      // No session back means the project is set to confirm addresses by
      // email before letting anyone in. The account exists either way.
      if (!data.session) {
        return "Account created. Check your email to confirm the address, then log in.";
      }
      return loadSession().then(() => "");
    });
}

function registerError(error) {
  console.error("Sign-up:", error);
  const message = (error.message || "").toLowerCase();

  if (message.includes("already registered") || message.includes("already been registered")) {
    return "An account with this email already exists.";
  }
  if (message.includes("invalid") && message.includes("email")) {
    return "That email address does not look right.";
  }
  if (message.includes("password")) {
    return "Password must be at least 6 characters.";
  }
  return "Could not create the account. Please try again.";
}

// ------------------------------------------------------------
// Logging in.
//
// Same message whether the email is unknown or the password is wrong,
// so nobody can use this to discover who has an account here. That was
// true of the PHP and it stays true: Supabase returns one error for
// both cases.
// ------------------------------------------------------------
function loginUser(email, password) {
  return sb.auth.signInWithPassword({
    email: (email || "").trim().toLowerCase(),
    password: password || "",
  }).then(({ error }) => {
    if (error) {
      console.error("Sign-in:", error);
      return "Incorrect email or password.";
    }
    // A staff account has no row in customers, so loadSession() finds
    // nothing and the old code called that a failure -- which left the
    // owner signing into their own shop and being told they could not.
    // The sign-in itself was fine; it is the wrong door, not a refusal.
    return loadSession().then((user) => {
      if (user) return "";
      return isStaffAccount().then((staff) => {
        if (!staff) return "That account cannot sign in to the shop.";
        // Staff, at the customers' door. The admin pages keep their
        // session under a different storage key on purpose -- so that
        // signing in as staff in one tab does not sign a customer out in
        // another -- which means this session cannot be carried over
        // there. It is released rather than left sitting in the shop's
        // storage belonging to somebody with no shop account.
        return sb.auth.signOut().then(() => "staff", () => "staff");
      });
    });
  });
}

function logoutUser() {
  sb.auth.signOut().finally(() => {
    currentUser = null;
    window.location.href = "index.html";
  });
}

// ------------------------------------------------------------
// Saving the profile.
//
// Three columns and no more. That is not politeness — UPDATE on this
// table is granted on exactly (name, phone, address), so a request
// trying to change the email or the account it belongs to is refused by
// Postgres rather than by this function.
// ------------------------------------------------------------
function updateProfile(fields) {
  if (!currentUser) return Promise.resolve("Please log in first.");

  const name = (fields.name || "").trim();
  if (name === "") return Promise.resolve("Name cannot be empty.");

  return sb.from("customers")
    .update({
      name,
      phone:   (fields.phone || "").trim(),
      address: (fields.address || "").trim(),
    })
    .eq("customer_id", currentUser.id)
    .then(({ error }) => {
      if (error) return dbMessage(error, "Could not save your details.");
      currentUser.name    = name;
      currentUser.phone   = (fields.phone || "").trim();
      currentUser.address = (fields.address || "").trim();
      return "";
    });
}

// Sends the customer to the login page, remembering where they were so
// they come back to it afterwards.
function askToLogIn(why) {
  const message = why || "Please log in to continue.";
  if (confirm(message + "\n\nGo to the login page now?")) {
    sessionStorage.setItem("returnTo", window.location.pathname.split("/").pop());
    window.location.href = "login.html";
  }
}

// Whether the account now signed in is shop staff.
//
// is_admin() is the same function every Row Level Security policy calls,
// so there is one answer to this rather than the page's opinion and the
// database's. It returns false for a customer and for nobody signed in.
// It is asked after signing in, never before: it is a question about who
// you are, not a way of finding out who works here.
function isStaffAccount() {
  return sb.rpc("is_admin")
    .then(({ data }) => data === true)
    .catch(() => false);
}
