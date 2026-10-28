# Chapter 4 screenshots to retake (after the 28 Oct fixes)

Take these on the live site, https://etech-fyp.vercel.app, once the branch is merged to `main`.
Figures 4.21, 4.34 and 4.36 also need the two database migrations applied first
(`20261028100000_order_payment_rules.sql`, `20261028110000_deal_audience.sql`); until then
those pages still behave the old way.

Use your own test customer account and a real order you placed for testing. Do not
use a real customer's order, and crop or blur names, emails, phone numbers and
addresses before the screenshot goes in the report (data agreement).

Figure 4.30 (Rig Showcase) stays out of Chapter 4, as agreed.

| Figure | Retake? | Why |
|---|---|---|
| 4.15 | Yes | New green success box |
| 4.21 | Yes | Order stages now follow payment; new "delivered" message |
| 4.22 | Only if the old one shows a different message | Wording unchanged |
| 4.23 | Yes | Socket filter now kept in the address bar |
| 4.24 | Yes | Wishlist page fixed |
| 4.31 | Optional | Same toast; new delivered message available |
| 4.33 | Yes | Revenue now counts confirmed payments only |
| 4.34 | Yes | Payment labels and buttons changed |
| 4.35 | Yes | New "Low and out of stock" table |
| 4.36 | Yes | Count now matches who is messaged; in-app vs push shown |
| 4.38 | Yes | Product Edit page redesigned |
| 4.39 | Yes | Add Brand / Add Category success message |

## 4.15 Registration success
1. Log out. Open **Register**.
2. Fill the form with a new address you can read (for example a `+test` alias of your Gmail).
3. Press **Create account**.
4. Capture the green box: "Account created successfully! Please check your email to verify your account before logging in."
5. Optional extra figure: open the confirmation email link. You land on **Login** with "Your email is confirmed…".

## 4.21 Order status and customer notification
1. As your test customer, place an order (Bank transfer, Delivery) and upload a receipt photo on **My Orders**.
2. As staff, open **Orders**. The card shows "Receipt sent: check it", and the Start preparing button is greyed with "Approve the payment first". Capture this; it is the fix.
3. Press **Approve payment**. The order moves to Processing.
4. Press **Mark shipped**, then **Mark delivered**.
5. As the customer, open the bell. Capture "Payment received", "Your order is on its way" and "Your order has been delivered", each once.

## 4.22 Password reset confirmation
1. Log out. **Login → Forgot your password?**
2. Enter any address and press the button.
3. Capture the green message: "If that address has an account, a link to set a new password is on its way…"

## 4.23 CPU + AMD + AM5 filtering
1. Open **Shop**. Tick **Components**, then Type **CPU**, then Brand **AMD**.
2. Open **Socket** and tick **AM5**.
3. Capture the grid with "9 products", the chips (Components, Type: CPU, Brand: AMD, Socket: AM5) and the address bar showing `spec.socket=AM5`.

## 4.24 Wishlist
1. Sign in as the test customer. Press the heart on two products.
2. Open **Wishlist** from the header. Capture the two cards and the header count of 2.
3. Optional: remove one and capture the count dropping to 1 with "Removed from your wishlist."

## 4.31 Real-time notification popup
1. Keep the customer signed in on one browser window.
2. In a second window, as staff, move one of their orders on (for example Mark shipped).
3. Capture the toast that slides up in the customer window without a reload.

## 4.33 Dashboard and Recent Orders
1. As staff, open **Dashboard**.
2. Capture the four cards. Total Revenue now shows confirmed payments, with a line underneath like "RM … more on N orders awaiting payment check".
3. Capture **Recent Orders** and **Sales Forecast** (labelled "this month" / "next month").

## 4.34 Staff payment approval
1. As staff, **Orders**, then the **Payment not checked** filter button. Pick the card whose badge reads "Receipt sent: check it".
2. Press **View receipt** so the photo shows, then capture the card with **Approve payment** / **Reject payment**.
3. Optional second shot after pressing Approve: the badge reads "Payment approved" and the order is Processing.

## 4.35 Low-stock alerts
1. As staff, open **Stock Alerts**.
2. Scroll to **Low and out of stock**. Capture the row for **AMD Ryzen 5 5500** (3 left, low-stock level 5) with its "Update stock" button.

## 4.36 Deal customer notification count
1. As the test customer, save a product to the wishlist (or put it in the cart).
2. As staff, **Timed Deals**: choose that product. Capture the hint under the price: "1 customer will be messaged (1 saved it); … also get a phone push."
3. Set a price below the list price and press create. Capture the message: "Deal created. 1 customer notified in the shop; N phone push(es) queued."
4. Switch the test deal off afterwards so it does not stay live in the shop.

## 4.38 Product Edit page
1. As staff, **Products → Edit** on any product with a photo (for example a GPU).
2. Capture the full page: details and price/stock on the left; photo, the amber "Internal: cost price" box with its margin, and the PC Builder switch on the right.

## 4.39 Add Brand and Add Category
1. On a new product (**Products → + Add product**), choose **+ Add New Brand** in the Brand list.
2. Type a brand, press Add. Capture the green "Brand "…" added and selected."
3. Choose **+ Add New Category**, pick **Under Components**, type **Capture Card**, press Add. Capture "Category "Components > Capture Card" added and selected."
4. Press **Cancel** so no half-made product is saved. Delete the test brand/category afterwards if you do not want them kept.
