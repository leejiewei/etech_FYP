-- ============================================================
-- Brute-force protection for the admin sign-in.
--
-- Without this, somebody can try passwords at the login page
-- forever. A short script can manage thousands of guesses a
-- minute, and "admin123" would not survive that for long.
--
-- Every failed attempt is written here. Once an account has
-- collected too many failures inside the time window, login.php
-- refuses to check the password at all until the window passes.
--
-- Run with:
--   C:\xampp\mysql\bin\mysql.exe -u root etech < 06_login_attempts.sql
-- ============================================================

USE etech;

DROP TABLE IF EXISTS login_attempts;

CREATE TABLE login_attempts (
  attempt_id   INT AUTO_INCREMENT PRIMARY KEY,
  username     VARCHAR(60)  NOT NULL,
  ip_address   VARCHAR(45)  NOT NULL,   -- 45 chars so an IPv6 address fits
  attempted_at DATETIME     NOT NULL,

  -- The lookup is always "failures for this username since <time>",
  -- so an index on that pair keeps it fast as the table grows.
  INDEX idx_user_time (username, attempted_at),
  INDEX idx_ip_time   (ip_address, attempted_at)
) ENGINE=InnoDB;

-- The admin panel connects as etech_admin, which already has full
-- rights on this database, so no extra GRANT is needed.
