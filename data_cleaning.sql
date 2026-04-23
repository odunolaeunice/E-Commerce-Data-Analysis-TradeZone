-- Data Cleaning Steps
-- 1. Handling missing values

-- missing values from customers table
DELETE FROM customers 
WHERE customer_id IS NULL;

-- missing values from order_items table
DELETE FROM order_items 
WHERE order_id IS NULL 
    OR item_id IS NULL 
	OR product_id IS NULL;

--  missing values from oders table
DELETE FROM orders 
WHERE order_id IS NULL
    OR customer_id IS NULL
	OR seller_id IS NULL;
   
-- missing values from payement table
DELETE FROM payments 
WHERE payment_id IS NULL
	OR order_id IS NULL;

-- missing values from products table
DELETE FROM products 
WHERE product_id IS NULL
    OR seller_id IS NULL
    OR product_name IS NULL 
	OR product_name = '';

-- missing values from reviews table
DELETE FROM reviews 
WHERE review_id IS NULL
    OR customer_id IS NULL
    OR order_id IS NULL
	OR rating IS NULL;

-- missing values from sellers table
DELETE FROM sellers 
WHERE seller_id IS NULL;

-- 2 Removing Duplicate Entries
-- Deduplicate Customers
DELETE FROM customers
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM customers
    GROUP BY customer_id
);

-- Deduplicate order_items
DELETE FROM order_items
WHERE ctid NOT IN (
	SELECT MIN(ctid)
	FROM order_items
	GROUP BY item_id
);

-- Deduplicate order
DELETE FROM orders
WHERE ctid NOT IN (
	SELECT MIN(ctid)
	FROM orders
	GROUP BY order_id
);

-- Deduplicate payments
DELETE FROM payments
WHERE ctid NOT IN (
	SELECT MIN(ctid)
	FROM payments
	GROUP BY payment_id
);

-- Deduplicate products
DELETE FROM products
WHERE ctid NOT IN (
	SELECT MIN(ctid)
	FROM products
	GROUP BY product_id
);

-- Deduplicate reviews
DELETE FROM reviews
WHERE ctid NOT IN (
	SELECT MIN(ctid)
	FROM reviews
	GROUP BY review_id
);
-- Deduplicate Sellers
DELETE FROM sellers
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM sellers
    GROUP BY seller_id
);

-- 3. INCONSISTENT FORMATTING
-- Standardising text and enforcing YYYY-MM-DD date formats

-- Standardising Customers Table to Title Case (and remove accidental spaces)
UPDATE customers 
SET city = INITCAP(TRIM(city)),
    state = INITCAP(TRIM(state)),
    first_name = INITCAP(TRIM(first_name)),
    last_name = INITCAP(TRIM(last_name)),
    account_status = INITCAP(TRIM(account_status));

-- Standardising Product Table to Title Case (and remove accidental spaces)
UPDATE products 
SET category = INITCAP(TRIM(category)),
    product_name = INITCAP(TRIM(product_name));

-- Standardising Payment Table to Title Case (and remove accidental spaces)
UPDATE payments 
SET payment_method = INITCAP(TRIM(payment_method));
	
-- Standardising Seller Table to Title Case (and remove accidental spaces)
UPDATE sellers 
SET city = INITCAP(TRIM(city)),
    state = INITCAP(TRIM(state)),
    seller_name = INITCAP(TRIM(seller_name));

-- Normalising Product Category Names to Title Case
UPDATE products 
SET category = INITCAP(TRIM(category));

-- Ensuring Date columns strictly follow YYYY-MM-DD format
ALTER TABLE customers 
ALTER COLUMN signup_date TYPE DATE USING signup_date::DATE;

ALTER TABLE orders 
ALTER COLUMN order_date TYPE DATE USING order_date::DATE;

-- 4. DATA VALIDATION
-- Verifying financial logic and valid data ranges

SELECT 
    o.order_id,
    o.total_amount AS stated_total,
    SUM(oi.unit_price * oi.quantity) AS calculated_total,
    ABS(o.total_amount - SUM(oi.unit_price * oi.quantity)) AS discrepancy_amount
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING ABS(o.total_amount - SUM(oi.unit_price * oi.quantity)) > 10;

-- Validation B: Check review ratings (Must be between 1 and 5)
-- Any rating outside this range is a system error and breaks our averages.
DELETE FROM reviews 
WHERE rating < 1 OR rating > 5;

-- Validation C: Check for negative product prices or discount > 100%
-- Note: Checked products, orders, and order_items tables. No discount column exists in this database schema, so only negative prices were validated.

-- 5 DATA RECOVERY
-- Recovering the missing unit_prices 
UPDATE order_items
SET unit_price = products.unit_price 
FROM products
WHERE order_items.product_id = products.product_id
    AND order_items.unit_price IS NULL;

-- Using unit_price to calculate and recover missing total amount
UPDATE orders
SET total_amount = calculated.true_total
FROM (
    SELECT order_id, SUM(unit_price * quantity) AS true_total
    FROM order_items
    GROUP BY order_id
) AS calculated
WHERE orders.order_id = calculated.order_id
  AND orders.total_amount IS NULL;

-- Recover missing payment amounts using the fixed orders table
UPDATE payments
SET amount = orders.total_amount
FROM orders
WHERE payments.order_id = orders.order_id
    AND payments.amount IS NULL;  
	
-- Recover missing order_items unit_price using the fixed orders table
UPDATE order_items
SET unit_price = (orders.total_amount / quantity)
FROM orders
WHERE order_items.order_id = orders.order_id
  AND order_items.unit_price IS NULL
  AND orders.total_amount IS NOT NULL;

-- Set Delivered items with missing prices to 0
-- order_items table
UPDATE order_items
SET unit_price = 0
FROM orders
WHERE order_items.order_id = orders.order_id
  AND order_items.unit_price IS NULL
  AND orders.order_status = 'Delivered';
 
-- orders table
UPDATE orders
SET total_amount = 0
WHERE total_amount IS NULL
  AND order_status = 'Delivered';

-- Delete null prices from cancelled/returned order
DELETE FROM order_items WHERE unit_price IS NULL;

DELETE FROM payments 
WHERE amount IS NULL 
   OR order_id IN (SELECT order_id FROM orders WHERE total_amount IS NULL);
   
DELETE FROM orders WHERE total_amount IS NULL;
