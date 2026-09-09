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
// WHAT THIS RETURNS, AND WHY IT IS NO LONGER A STRING
//
// It used to return "" for success and a sentence for a failure, which
// worked only while every sign-up ended with the customer signed in.
// With email confirmation switched on there is a third outcome — the
// account was made, correctly, and the customer must now go and read
// their email — and it is neither of the other two. Returned as a
// string it would have been shown in the red error box, telling somebody
// their sign-up failed at the exact moment it had succeeded.
//
// So the answer is an object:
//
//   { ok: true,  message: "" }              signed in, carry on
//   { ok: true,  message: "Check your …" }  made, needs confirming
//   { ok: false, message: "…" }             refused, show it as an error
//
// ok says which box to put the message in. message is what to write in
// it.
// ------------------------------------------------------------
function registerUser(name, email, password) {
  name = (name || "").trim();
  email = (email || "").trim().toLowerCase();

  // The same three checks the PHP made, kept here so the wording the
  // customer sees does not change. Supabase enforces its own versions
  // as well; these just get in first with a friendlier sentence.
  if (name === "" || email === "" || !password) {
    return Promise.resolve({ ok: false, message: "Please fill in every field." });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return Promise.resolve({ ok: false, message: "That email address does not look right." });
  }
  // Matches auth.minimum_password_length in supabase/config.toml. If the
  // two ever drift, Supabase wins and the customer gets its wording
  // instead of ours.
  if (password.length < 8) {
    return Promise.resolve({ ok: false, message: "Password must be at least 8 characters." });
  }

  return sb.auth.signUp({ email, password, options: { data: { name } } })
    .then(({ data, error }) => {
      if (error) return { ok: false, message: registerError(error) };

      // No session back means the project is set to confirm addresses by
      // email before letting anyone in. The account exists either way.
      //
      // This is now the normal path, not the unusual one: confirmation is
      // on, so a new customer always lands here and is sent to their
      // inbox. The link in that email expires in fifteen minutes
      // (auth.email.otp_expiry).
      if (!data.session) {
        return {
          ok: true,
          message: "Account created. Check your email to confirm the address, then log in. " +
                   "The link expires in 15 minutes.",
        };
      }
      return loadSession().then(claimEarlierActivity).then(() => ({ ok: true, message: "" }));
    });
}

// ------------------------------------------------------------
// Whatever this browser did before it had an account.
//
// Someone browses, decides to buy, and only then signs up. Their
// browsing was filed under the browser's anon_id and belongs to nobody;
// this hands it to them, so the purchase has the visits that led to it
// attached rather than arriving out of nowhere.
//
// Waited on rather than fired and forgotten: both callers redirect
// immediately afterwards, and a request still in flight when the page
// navigates away is cancelled. It is one round trip. A failure is
// swallowed — losing the join is a worse dataset, not a failed login,
// and the customer must not be shown an error about it.
// ------------------------------------------------------------
function claimEarlierActivity(user) {
  if (!user || typeof claimAnonActivity !== "function") return Promise.resolve(user);
  return claimAnonActivity().then(() => user, () => user);
}

// ------------------------------------------------------------
// Why this does not say "that email is already registered".
//
// It used to, and it was the one place on the site that would tell a
// stranger whether a given person shops here. Type an address, read the
// answer, repeat: that is account enumeration, and a list of confirmed
// customer addresses is worth having to somebody running a phishing or
// credential-stuffing campaign. The login page has never had this
// problem -- it answers "Incorrect email or password." to both a wrong
// password and an unknown address -- and sign-up should not undo that.
//
// So a duplicate address now gets the same sentence a new one does, and
// the customer is pointed at the login page rather than told why.
// Someone who genuinely forgot they had an account still gets there in
// one click; someone probing gets nothing back to distinguish the two.
//
// Two honest limits, because this is a mitigation and not a cure:
//
//   * Supabase Auth still answers the underlying HTTP call differently
//     for a known address while email confirmations are off. Closing
//     that needs enable_confirmations = true, which would put every beta
//     tester behind a confirmation email and the project's mail
//     allowance is two per hour. Not worth breaking the beta over.
//   * Faults are folded in with duplicates here. That is the price of a
//     single sentence; the real error still goes to the console.
// ------------------------------------------------------------
function registerError(error) {
  console.error("Sign-up:", error);
  const message = (error.message || "").toLowerCase();

  // Both of these are facts about what the customer just typed, not
  // about who already has an account, so they stay specific.
  if (message.includes("invalid") && message.includes("email")) {
    return "That email address does not look right.";
  }
  if (message.includes("password")) {
    return "Password must be at least 8 characters.";
  }

  return "Could not create the account. If you have signed up before, " +
         "please log in instead.";
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
    return loadSession().then(claimEarlierActivity).then((user) => {
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

// ------------------------------------------------------------
// Changing the password, and what has to happen to the other sessions.
//
// Supabase issues a session per device, each one a signed token that
// keeps working on its own until it expires -- refreshing itself
// quietly in the background for as long as the browser holding it is
// open. Nothing about changing the password invalidates them. So a
// customer who changes their password *because* they think somebody
// else is in the account would, by default, achieve nothing at all: the
// intruder's phone carries on refreshing its token and stays signed in.
//
// That is the whole point of this function. updateUser sets the new
// password; signOut({ scope: "others" }) then revokes every session
// except the one doing the changing, so the customer stays logged in
// here and everything else is thrown out. "others" rather than "global"
// deliberately -- being signed out of the page you are standing on,
// immediately after successfully changing your password, reads as a
// failure.
//
// The current password is asked for and checked first, by signing in
// with it. Without that, anyone who found an unlocked laptop could set
// a new password from this page and take the account -- and the
// revocation above would then be working for them, not against them.
// Supabase can enforce this itself (auth.email.secure_password_change),
// and that is set too; this is the same guard on the near side, where
// it can say something useful when it fails.
//
// Returns "" when it worked, or a message to show the customer.
// ------------------------------------------------------------
function changePassword(currentPassword, newPassword, confirmPassword) {
  if (!currentUser) return Promise.resolve("Please log in first.");

  if (!currentPassword || !newPassword) {
    return Promise.resolve("Please fill in every field.");
  }
  if (newPassword.length < 8) {
    return Promise.resolve("New password must be at least 8 characters.");
  }
  if (newPassword !== confirmPassword) {
    return Promise.resolve("The two new passwords do not match.");
  }
  if (newPassword === currentPassword) {
    return Promise.resolve("The new password must be different from the old one.");
  }

  // Prove the person at the keyboard knows the password they are
  // replacing. A wrong answer here ends it before updateUser is called.
  return sb.auth.signInWithPassword({
    email: currentUser.email,
    password: currentPassword,
  }).then(({ error }) => {
    if (error) {
      console.error("Re-authenticating before password change:", error);
      return "Your current password is not correct.";
    }

    return sb.auth.updateUser({ password: newPassword }).then(({ error: updateError }) => {
      if (updateError) {
        console.error("Password change:", updateError);
        const message = (updateError.message || "").toLowerCase();
        if (message.includes("weak") || message.includes("password")) {
          return "Please choose a stronger password.";
        }
        return "Could not change the password. Please try again.";
      }

      // The reason this function exists. A failure here is not a failed
      // password change -- the new password is already saved -- but the
      // customer must be told, because the old sessions are the thing
      // they were trying to get rid of.
      return sb.auth.signOut({ scope: "others" }).then(
        () => "",
        (signOutError) => {
          console.error("Revoking other sessions:", signOutError);
          return "Password changed, but other devices may still be signed in. " +
                 "Please change it again from a different device.";
        }
      );
    });
  });
}

// ------------------------------------------------------------
// Forgetting the password.
//
// Until now there was no way back into an account whose password had
// been lost. Nothing stores the password — auth.users holds a bcrypt
// hash and nothing else — so it cannot be looked up and told to
// anybody, not by the shop and not by the owner. The only way in is to
// set a new one, and the only thing that proves the person asking owns
// the account is that they can read its email.
//
// That matters more during the beta than it would later. A tester who
// registers on the day, mistypes the password they meant to use, and
// closes the tab is otherwise finished — there is no second account to
// make with the same address, and no owner who can read the old
// password back to them.
//
// WHY THIS ALWAYS SAYS THE SAME THING
//
// The answer is identical whether the address has an account or not,
// for the reason registerError() gives at length: an honest "no such
// account" here would hand back exactly the account-enumeration oracle
// that sign-up was changed to stop giving. So the sentence below is
// returned for a hit, for a miss, and for most failures, and the real
// error goes to the console where only the shop can read it.
//
// Two limits worth knowing, both of them the project's mail allowance
// rather than anything in this file:
//
//   * A hundred auth emails an hour, project-wide, counting resends and
//     every confirmation the shop sends. That is the hosted project's
//     figure, set alongside custom SMTP on 7 September. Do not read it
//     out of supabase/config.toml, which still says two: that file
//     configures a local stack and has never described the deployed
//     project.
//   * One a minute per address (auth.email.max_frequency), and the link
//     expires fifteen minutes after it is sent (auth.email.otp_expiry).
//
// Returns a message to show the customer either way; there is no error
// case for them to act on.
// ------------------------------------------------------------
const RESET_SENT_MESSAGE =
  "If that address has an account, a link to set a new password is on its way. " +
  "It expires in 15 minutes, and it may take a minute to arrive — check the spam folder " +
  "before asking for another.";

function requestPasswordReset(email) {
  email = (email || "").trim().toLowerCase();

  // A malformed address is a fact about what was typed, not about who
  // has an account, so this one stays specific.
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return Promise.resolve({ ok: false, message: "That email address does not look right." });
  }

  // Where the link in the email should land. Built from the page asking
  // rather than hard-coded, so the same file works on localhost and on
  // the deployed site without either being written down here. Supabase
  // will only honour it if the exact URL is in the project's redirect
  // allow-list; if it is not, the link falls back to the Site URL and
  // arrives on a page that cannot finish the job.
  const here = window.location.origin + window.location.pathname.replace(/[^/]*$/, "");

  return sb.auth.resetPasswordForEmail(email, { redirectTo: here + "reset-password.html" })
    .then(({ error }) => {
      if (error) console.error("Password reset request:", error);
      // Deliberately the same answer either way. See above.
      return { ok: true, message: RESET_SENT_MESSAGE };
    })
    .catch((error) => {
      console.error("Password reset request:", error);
      return { ok: true, message: RESET_SENT_MESSAGE };
    });
}

// ------------------------------------------------------------
// Setting the new password.
//
// Called by reset-password.html, and only once that page has satisfied
// itself that this browser arrived holding a recovery link. That check
// belongs to the page rather than here because the evidence — the
// token in the URL — is gone by the time this runs: the Supabase client
// reads it, turns it into a session, and clears it out of the address
// bar so it cannot be shoulder-read or left in history.
//
// The session that recovery link created is an ordinary one. That is
// what makes updateUser work without the old password, and it is also
// why the page must not offer this form to somebody who merely happens
// to be signed in already — that would be changePassword() with its
// guard taken off, and an unlocked laptop would be enough to take the
// account. changePassword() is still the right function for a customer
// who knows their password and wants a different one.
//
// signOut({ scope: "others" }) for the same reason it is in
// changePassword(): somebody resetting a password they think another
// person has must actually get that person out, and the recovery
// session is the one to keep.
//
// Returns "" when it worked, or a message to show the customer.
// ------------------------------------------------------------
function completePasswordReset(newPassword, confirmPassword) {
  if (!newPassword) {
    return Promise.resolve("Please fill in every field.");
  }
  if (newPassword.length < 8) {
    return Promise.resolve("New password must be at least 8 characters.");
  }
  if (newPassword !== confirmPassword) {
    return Promise.resolve("The two passwords do not match.");
  }

  return sb.auth.updateUser({ password: newPassword }).then(({ error }) => {
    if (error) {
      console.error("Password reset:", error);
      const message = (error.message || "").toLowerCase();
      // The link having gone stale between opening the page and
      // submitting it is the likely failure here, and it is the one the
      // customer can do something about.
      if (message.includes("expired") || message.includes("invalid") || message.includes("session")) {
        return "That link has expired. Please ask for a new one.";
      }
      if (message.includes("weak") || message.includes("password")) {
        return "Please choose a stronger password.";
      }
      return "Could not set the new password. Please try again.";
    }

    return sb.auth.signOut({ scope: "others" }).then(
      () => "",
      (signOutError) => {
        console.error("Revoking other sessions:", signOutError);
        return "Password set, but other devices may still be signed in. " +
               "Please change it again from your profile once you are in.";
      }
    );
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
