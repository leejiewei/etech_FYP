-- ============================================================
-- eTech Computer Accessories - database schema
-- Run this first:  mysql -u root < 01_schema.sql
--
-- Everything uses InnoDB so we get real foreign keys, and utf8mb4
-- so product names keep their emoji and quote marks.
-- ============================================================

DROP DATABASE IF EXISTS etech;
CREATE DATABASE etech CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE etech;

-- ------------------------------------------------------------
-- Look-up tables
-- ------------------------------------------------------------

-- Brands (AMD, Asus, MSI, ...). Kept in their own table so the
-- BRANDS menu and the brand filter read from one place.
CREATE TABLE brands (
  brand_id   INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(60) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Categories, with parent_id pointing at another category so a
-- sub-category like "CPU" can sit under "Components".
CREATE TABLE categories (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(60) NOT NULL,
  parent_id   INT NULL,
  UNIQUE KEY uq_category (name, parent_id),
  CONSTRAINT fk_category_parent FOREIGN KEY (parent_id)
    REFERENCES categories(category_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Products
-- ------------------------------------------------------------
CREATE TABLE products (
  product_id   INT PRIMARY KEY,               -- keeps the ids already used by images/<id>.jpg
  name         VARCHAR(200) NOT NULL,
  brand_id     INT NOT NULL,
  category_id  INT NOT NULL,
  price        DECIMAL(10,2) NOT NULL,        -- what the customer pays

  -- Not recorded yet. Needed for the margin figures and for the
  -- "high-cost stagnant item" test in the dead-stock alerts.
  cost_price   DECIMAL(10,2) NULL,

  -- Real counts aren't recorded yet either, so stock_status is the
  -- field the shop actually uses today. Once stock_qty is filled in,
  -- status should be worked out from it (out at 0, low at or below
  -- reorder_level, otherwise in).
  stock_qty     INT NULL,
  reorder_level INT NOT NULL DEFAULT 5,
  stock_status  ENUM('in','low','out') NOT NULL DEFAULT 'in',

  description  TEXT,
  icon         VARCHAR(16),                   -- emoji fallback
  img_slug     VARCHAR(40),                   -- images/<slug>.svg drawing
  image_path   VARCHAR(255) NULL,             -- a real uploaded photo, once there is one

  -- Sold in the shop but never offered in Own Build: legacy boards,
  -- laptop memory, DDR3 repair sticks, surveillance drives.
  exclude_from_builder TINYINT(1) NOT NULL DEFAULT 0,

  is_active    TINYINT(1) NOT NULL DEFAULT 1, -- soft delete, so old orders keep their product
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_product_brand    FOREIGN KEY (brand_id)    REFERENCES brands(brand_id),
  CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES categories(category_id),
  INDEX idx_product_category (category_id),
  INDEX idx_product_brand (brand_id)
) ENGINE=InnoDB;

-- Technical specs. Products differ wildly (a printer has no socket,
-- a CPU has no paper size), so rather than hundreds of mostly-empty
-- columns each spec is a row. A spec that holds several values, like
-- a cooler's socket list, is simply several rows with the same key.
CREATE TABLE product_attributes (
  attribute_id INT AUTO_INCREMENT PRIMARY KEY,
  product_id   INT NOT NULL,
  attr_key     VARCHAR(40) NOT NULL,          -- 'socket', 'ramGen', 'wattage', ...
  attr_value   VARCHAR(120) NOT NULL,
  CONSTRAINT fk_attr_product FOREIGN KEY (product_id)
    REFERENCES products(product_id) ON DELETE CASCADE,
  INDEX idx_attr_lookup (attr_key, attr_value),
  INDEX idx_attr_product (product_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- People
-- ------------------------------------------------------------
CREATE TABLE customers (
  customer_id   INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(120) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,        -- PHP password_hash(), never the raw password
  phone         VARCHAR(30),
  address       TEXT,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Shop staff. Separate table so a customer can never become an admin
-- by editing their own row.
CREATE TABLE admins (
  admin_id      INT AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(60) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name          VARCHAR(100) NOT NULL,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Promotions
-- ------------------------------------------------------------
-- Creating one of these is what triggers the customer notification.
-- category_id NULL means the coupon applies to everything.
CREATE TABLE coupons (
  coupon_id        INT AUTO_INCREMENT PRIMARY KEY,
  code             VARCHAR(30) NOT NULL UNIQUE,
  description      VARCHAR(160),
  category_id      INT NULL,
  discount_percent DECIMAL(5,2) NOT NULL,
  starts_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ends_at          DATETIME NULL,
  is_active        TINYINT(1) NOT NULL DEFAULT 1,
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_coupon_category FOREIGN KEY (category_id)
    REFERENCES categories(category_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Orders
-- ------------------------------------------------------------
CREATE TABLE orders (
  order_id         INT AUTO_INCREMENT PRIMARY KEY,
  customer_id      INT NOT NULL,
  order_date       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status           ENUM('Pending','Processing','Shipped','Delivered','Cancelled')
                     NOT NULL DEFAULT 'Pending',
  subtotal         DECIMAL(10,2) NOT NULL,
  discount         DECIMAL(10,2) NOT NULL DEFAULT 0,
  total            DECIMAL(10,2) NOT NULL,
  coupon_code      VARCHAR(30) NULL,
  -- copied at checkout so a later profile edit can't rewrite history
  shipping_name    VARCHAR(100),
  shipping_phone   VARCHAR(30),
  shipping_address TEXT,
  CONSTRAINT fk_order_customer FOREIGN KEY (customer_id)
    REFERENCES customers(customer_id),
  INDEX idx_order_date (order_date),
  INDEX idx_order_status (status)
) ENGINE=InnoDB;

-- Name and price are copied in, so an order still reads correctly
-- years later even if the product is renamed, repriced or removed.
CREATE TABLE order_items (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id      INT NOT NULL,
  product_id    INT NULL,                     -- NULL for a prebuilt bundle
  product_name  VARCHAR(200) NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL,
  unit_cost     DECIMAL(10,2) NULL,           -- cost at the time of sale, for margin
  quantity      INT NOT NULL,
  line_total    DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_item_order   FOREIGN KEY (order_id)   REFERENCES orders(order_id) ON DELETE CASCADE,
  CONSTRAINT fk_item_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE SET NULL,
  INDEX idx_item_product (product_id)
) ENGINE=InnoDB;

-- Every status change, so the admin can see when an order moved on
-- and who moved it.
CREATE TABLE order_status_history (
  history_id  INT AUTO_INCREMENT PRIMARY KEY,
  order_id    INT NOT NULL,
  status      ENUM('Pending','Processing','Shipped','Delivered','Cancelled') NOT NULL,
  changed_by  INT NULL,
  note        VARCHAR(200),
  changed_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_history_order FOREIGN KEY (order_id)  REFERENCES orders(order_id) ON DELETE CASCADE,
  CONSTRAINT fk_history_admin FOREIGN KEY (changed_by) REFERENCES admins(admin_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Basket and wishlist (kept server-side so they follow the customer)
-- ------------------------------------------------------------
CREATE TABLE cart_items (
  customer_id INT NOT NULL,
  product_id  INT NOT NULL,
  quantity    INT NOT NULL DEFAULT 1,
  added_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id, product_id),
  CONSTRAINT fk_cart_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
  CONSTRAINT fk_cart_product  FOREIGN KEY (product_id)  REFERENCES products(product_id)  ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE wishlist_items (
  customer_id INT NOT NULL,
  product_id  INT NOT NULL,
  added_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id, product_id),
  CONSTRAINT fk_wish_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
  CONSTRAINT fk_wish_product  FOREIGN KEY (product_id)  REFERENCES products(product_id)  ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Behaviour tracking  -->  feeds the Inventory Velocity module
-- ------------------------------------------------------------
-- One row per thing a shopper does. The velocity score weights them:
--   view 1, cart add 3, purchase 5.
CREATE TABLE events (
  event_id    BIGINT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NULL,                       -- NULL = not signed in
  product_id  INT NOT NULL,
  event_type  ENUM('view','cart_add','wishlist_add','purchase') NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_event_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE SET NULL,
  CONSTRAINT fk_event_product  FOREIGN KEY (product_id)  REFERENCES products(product_id)  ON DELETE CASCADE,
  INDEX idx_event_product (product_id, event_type),
  INDEX idx_event_date (created_at)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Chatbot transcript, shown in the admin panel
-- ------------------------------------------------------------
CREATE TABLE chatbot_logs (
  log_id      BIGINT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NULL,
  question    TEXT NOT NULL,
  answer      TEXT NOT NULL,
  was_build_request TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_log_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE SET NULL,
  INDEX idx_log_date (created_at)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Views used by the dashboard
-- ------------------------------------------------------------

-- Inventory Velocity. This is LFU (least-frequently-used) turned around:
-- instead of finding what to throw away, we rank what customers engage
-- with most. score = views x1 + cart adds x3 + purchases x5
-- IFNULL keeps a product with no activity at 0 rather than NULL, so the
-- untouched stock still sorts properly at the bottom of the ranking —
-- which is exactly what the dead-stock alert needs to find.
CREATE OR REPLACE VIEW v_product_velocity AS
SELECT
  p.product_id,
  p.name,
  p.price,
  p.stock_status,
  IFNULL(SUM(e.event_type = 'view'),     0) AS views,
  IFNULL(SUM(e.event_type = 'cart_add'), 0) AS cart_adds,
  IFNULL(SUM(e.event_type = 'purchase'), 0) AS purchases,
  IFNULL(SUM(e.event_type = 'view')     * 1, 0)
+ IFNULL(SUM(e.event_type = 'cart_add') * 3, 0)
+ IFNULL(SUM(e.event_type = 'purchase') * 5, 0) AS velocity_score,
  MAX(e.created_at) AS last_activity
FROM products p
LEFT JOIN events e ON e.product_id = p.product_id
WHERE p.is_active = 1
GROUP BY p.product_id, p.name, p.price, p.stock_status;

-- Everything sold, by month, for the sales trend chart.
CREATE OR REPLACE VIEW v_monthly_sales AS
SELECT
  DATE_FORMAT(o.order_date, '%Y-%m') AS month,
  COUNT(DISTINCT o.order_id)         AS orders,
  SUM(oi.quantity)                   AS units,
  SUM(oi.line_total)                 AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'Cancelled'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m');

SELECT 'Schema created.' AS status;
