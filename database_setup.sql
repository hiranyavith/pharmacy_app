-- ============================================
-- Pharmacy MVP - MySQL Database Setup
-- Run this in MySQL before starting the app
-- ============================================

CREATE DATABASE IF NOT EXISTS pharmacy_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE pharmacy_db;

-- Users table (admin login)
CREATE TABLE IF NOT EXISTS users (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50)  NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Medicines table
CREATE TABLE IF NOT EXISTS medicines (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(150) NOT NULL,
  category    VARCHAR(80),
  price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  stock       INT           NOT NULL DEFAULT 0,
  expiry_date DATE,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Bills (invoice header)
CREATE TABLE IF NOT EXISTS bills (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  invoice_no VARCHAR(30) NOT NULL UNIQUE,
  subtotal   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  discount   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bill line items
CREATE TABLE IF NOT EXISTS bill_items (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  bill_id     INT NOT NULL,
  medicine_id INT NOT NULL,
  med_name    VARCHAR(150),
  quantity    INT           NOT NULL,
  unit_price  DECIMAL(10,2) NOT NULL,
  line_total  DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (bill_id)     REFERENCES bills(id)     ON DELETE CASCADE,
  FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE RESTRICT
);

-- ── Seed data ──────────────────────────────

-- Default admin  (password: admin123)
INSERT IGNORE INTO users (username, password)
VALUES ('admin', 'admin123');

-- Sample medicines
INSERT IGNORE INTO medicines (name, category, price, stock, expiry_date) VALUES
  ('Paracetamol 500mg',   'Analgesic',    25.00, 200, DATE_ADD(CURDATE(), INTERVAL 60  DAY)),
  ('Amoxicillin 250mg',   'Antibiotic',   45.00, 150, DATE_ADD(CURDATE(), INTERVAL 20  DAY)),
  ('Ibuprofen 400mg',     'Analgesic',    30.00,  10, DATE_ADD(CURDATE(), INTERVAL 180 DAY)),
  ('Cetirizine 10mg',     'Antihistamine',18.00,  80, DATE_ADD(CURDATE(), INTERVAL 15  DAY)),
  ('Omeprazole 20mg',     'Antacid',      55.00, 120, DATE_ADD(CURDATE(), INTERVAL 365 DAY)),
  ('Metformin 500mg',     'Antidiabetic', 35.00,  60, DATE_ADD(CURDATE(), INTERVAL 90  DAY)),
  ('Atorvastatin 10mg',   'Cholesterol',  70.00,  45, DATE_ADD(CURDATE(), INTERVAL 25  DAY)),
  ('Vitamin C 500mg',     'Supplement',   15.00, 300, DATE_ADD(CURDATE(), INTERVAL 730 DAY));
