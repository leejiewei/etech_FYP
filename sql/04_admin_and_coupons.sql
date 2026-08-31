-- ============================================================
-- Starter admin login and the promotions already on the site.
-- Run after 03_seed.sql:  mysql -u root < 04_admin_and_coupons.sql
-- ============================================================

USE etech;

-- ------------------------------------------------------------
-- Shop staff login
-- ------------------------------------------------------------
-- The hash below was produced by PHP's password_hash() and is the
-- bcrypt of "admin123". The plain password is never stored, and PHP's
-- password_verify() is what checks it at login.
--
-- CHANGE THIS before the project is shown or hosted anywhere.
DELETE FROM admins WHERE username = 'admin';
INSERT INTO admins (username, password_hash, name) VALUES
  ('admin', '$2y$10$g8S0lT1ndqp7cIn17uybDeuiSN.ue2Zr3qmVyZ53Y/KngxMuN7aaO', 'Shop Administrator');

-- ------------------------------------------------------------
-- Promotions
-- ------------------------------------------------------------
-- These are the coupons the site already offered. Creating one of
-- these from the admin panel is what fires the customer notification,
-- so they are tied to a category.
DELETE FROM coupons;
INSERT INTO coupons (code, description, category_id, discount_percent, ends_at) VALUES
  ('LAPTOP15', '15% off all laptops',
     (SELECT category_id FROM categories WHERE name='Laptops'     AND parent_id IS NULL), 15.00, DATE_ADD(NOW(), INTERVAL 30 DAY)),
  ('PARTS10',  '10% off PC components',
     (SELECT category_id FROM categories WHERE name='Components'  AND parent_id IS NULL), 10.00, DATE_ADD(NOW(), INTERVAL 30 DAY)),
  ('GEAR20',   '20% off gaming gear',
     (SELECT category_id FROM categories WHERE name='Gaming Gear' AND parent_id IS NULL), 20.00, DATE_ADD(NOW(), INTERVAL 30 DAY)),
  ('SCREEN12', '12% off monitors',
     (SELECT category_id FROM categories WHERE name='Monitors'    AND parent_id IS NULL), 12.00, DATE_ADD(NOW(), INTERVAL 30 DAY)),
  ('NET10',    '10% off networking gear',
     (SELECT category_id FROM categories WHERE name='Networking'  AND parent_id IS NULL), 10.00, DATE_ADD(NOW(), INTERVAL 30 DAY)),
  ('PRINT10',  '10% off printers',
     (SELECT category_id FROM categories WHERE name='Printers'    AND parent_id IS NULL), 10.00, DATE_ADD(NOW(), INTERVAL 30 DAY));

SELECT
  (SELECT COUNT(*) FROM admins)  AS admin_accounts,
  (SELECT COUNT(*) FROM coupons) AS coupons;
