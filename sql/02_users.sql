-- ============================================================
-- Database accounts
--
-- Two logins with very different powers. The customer-facing pages
-- connect as etech_client, the admin panel as etech_admin.
--
-- The point: even if someone tampered with the customer-side code in
-- their browser, MySQL itself refuses to let that connection change a
-- price, delete a product, or read what we paid for stock. The limit
-- is enforced by the database, not just by the application.
--
-- Run after 01_schema.sql:  mysql -u root < 02_users.sql
-- ============================================================

-- Start clean so this file can be re-run safely
DROP USER IF EXISTS 'etech_admin'@'localhost';
DROP USER IF EXISTS 'etech_client'@'localhost';

CREATE USER 'etech_admin'@'localhost'  IDENTIFIED BY 'etech_admin_2026';
CREATE USER 'etech_client'@'localhost' IDENTIFIED BY 'etech_client_2026';

-- ------------------------------------------------------------
-- ADMIN — full control of everything
-- ------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON etech.* TO 'etech_admin'@'localhost';

-- ------------------------------------------------------------
-- CLIENT — read the shop, place orders, manage its own basket
-- ------------------------------------------------------------

-- Catalogue: read only. Note the column list on products — it names
-- every column EXCEPT cost_price, so the customer connection cannot
-- see our buying price even with a hand-written query.
GRANT SELECT (product_id, name, brand_id, category_id, price,
              stock_qty, reorder_level, stock_status, description,
              icon, img_slug, image_path, exclude_from_builder,
              is_active, created_at, updated_at)
  ON etech.products TO 'etech_client'@'localhost';

GRANT SELECT ON etech.product_attributes TO 'etech_client'@'localhost';
GRANT SELECT ON etech.categories         TO 'etech_client'@'localhost';
GRANT SELECT ON etech.brands             TO 'etech_client'@'localhost';

-- Promotions: read only. Customers can use a coupon, never create one.
GRANT SELECT ON etech.coupons TO 'etech_client'@'localhost';

-- Its own account. No DELETE, so an account can't be wiped from the
-- shop front. The application still checks you only touch your own row.
GRANT SELECT, INSERT, UPDATE ON etech.customers TO 'etech_client'@'localhost';

-- Ordering: may place an order and look it up, but not alter or remove
-- one afterwards. Only staff move an order along its stages.
GRANT SELECT, INSERT ON etech.orders      TO 'etech_client'@'localhost';
GRANT SELECT, INSERT ON etech.order_items TO 'etech_client'@'localhost';
GRANT SELECT         ON etech.order_status_history TO 'etech_client'@'localhost';

-- Basket and wishlist are the customer's own, so full control there.
GRANT SELECT, INSERT, UPDATE, DELETE ON etech.cart_items     TO 'etech_client'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON etech.wishlist_items TO 'etech_client'@'localhost';

-- Tracking and chat: write only. The shop front records what happened
-- but has no business reading everyone else's behaviour.
GRANT INSERT ON etech.events       TO 'etech_client'@'localhost';
GRANT INSERT ON etech.chatbot_logs TO 'etech_client'@'localhost';

-- Deliberately NOT granted to etech_client:
--   * anything at all on etech.admins        (staff accounts are invisible)
--   * products.cost_price                    (our margins)
--   * INSERT/UPDATE/DELETE on products       (no editing prices or stock)
--   * UPDATE/DELETE on orders                (no self-promoting to "Delivered")
--   * SELECT on events / chatbot_logs        (no reading other customers)
--   * the reporting views                    (admin dashboard only)

FLUSH PRIVILEGES;

SELECT 'Users created.' AS status;
