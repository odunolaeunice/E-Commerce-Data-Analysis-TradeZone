-- Question 1: Customer Acquisition & 30-Day Conversion
-- Finds top 5 states by 2024 sign-ups and their 30-day conversion rate
WITH New_2024_Customers AS (
    SELECT customer_id, state, signup_date
    FROM customers
    WHERE signup_date BETWEEN '2024-01-01' AND '2024-12-31'
),
Top_5_States AS (
    SELECT state, COUNT(customer_id) as signup_count
    FROM New_2024_Customers
    GROUP BY state
    ORDER BY signup_count DESC
    LIMIT 5
),
First_Orders AS (
    SELECT customer_id, MIN(order_date) as first_purchase_date
    FROM orders
    GROUP BY customer_id
)
SELECT 
    ts.state,
    ts.signup_count,
    COUNT(fo.customer_id) FILTER (WHERE fo.first_purchase_date <= nc.signup_date + INTERVAL '30 days') AS converted_customers,
    ROUND(COUNT(fo.customer_id) FILTER (WHERE fo.first_purchase_date <= nc.signup_date + INTERVAL '30 days') * 100.0 / ts.signup_count, 2) AS conversion_rate_pct
FROM Top_5_States ts
JOIN New_2024_Customers nc ON ts.state = nc.state
LEFT JOIN First_Orders fo ON nc.customer_id = fo.customer_id
GROUP BY ts.state, ts.signup_count
ORDER BY signup_count DESC;

--Question 2: Product Performance
-- Identifies top 10 products by 2024 revenue
SELECT 
    p.product_name,
    p.category,
    SUM(oi.unit_price * oi.quantity) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_date >= '2024-01-01' AND o.order_date < '2025-01-01'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 10;

--Question 3: Seller Fulfilment Efficiency
-- Top 20 fastest sellers (min 20 orders) with ratings
SELECT 
    s.seller_name,
    COUNT(o.order_id) AS total_completed_orders,
    -- Subtracting timestamps gives an interval, which EXTRACT loves!
    ROUND(AVG(EXTRACT(EPOCH FROM (o.delivery_date::timestamp - o.order_date::timestamp))/3600)::numeric, 2) AS avg_delivery_hours,
    ROUND(AVG(r.rating), 1) AS avg_rating
FROM sellers s
JOIN orders o ON s.seller_id = o.seller_id
LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE o.delivery_date IS NOT NULL
GROUP BY s.seller_id, s.seller_name
HAVING COUNT(o.order_id) >= 20
ORDER BY avg_delivery_hours ASC
LIMIT 20;

-- Question 4: Quarterly Revenue Trends
-- Quarterly revenue, AOV, and volume for 2023 vs 2024
WITH Unique_Orders AS (
    SELECT 
        order_id,
        order_date,
        total_amount
    FROM orders
    WHERE order_date >= '2023-01-01' AND order_date < '2025-01-01'
)
SELECT 
    EXTRACT(YEAR FROM order_date) AS yr,
    EXTRACT(QUARTER FROM order_date) AS qtr,
    SUM(total_amount) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    COUNT(DISTINCT order_id) AS total_orders
FROM Unique_Orders
GROUP BY yr, qtr
ORDER BY yr, qtr;

--Question 5: Customer Spend Segmentation
-- Segments 2024 customers by spend level
WITH Customer_Spend AS (
    SELECT 
        customer_id, 
        SUM(total_amount) as total_spend
    FROM orders
    WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
    GROUP BY customer_id
),
Segments AS (
    SELECT 
        customer_id,
        total_spend,
        CASE 
            WHEN total_spend >= 100000 THEN 'High Spender'
            WHEN total_spend >= 50000 THEN 'Medium Spender'
            ELSE 'Low Spender'
        END AS spend_group
    FROM Customer_Spend
)
SELECT 
    spend_group,
    COUNT(DISTINCT customer_id) AS customer_count,
    ROUND(AVG(total_spend), 2) AS avg_spend_per_customer,
    SUM(total_spend) AS total_revenue_contribution
FROM Segments
GROUP BY spend_group;

--Question 6: Payment Method Preferences by State
-- Most popular payment methods per state
SELECT 
    c.state,
    p.payment_method,
    COUNT(p.payment_id) AS transaction_count,
    SUM(p.amount) AS total_amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.state, p.payment_method
ORDER BY c.state, transaction_count DESC;

-- Question 7: Fixed Ambiguous Column
WITH Product_Ratings AS (
    SELECT 
        oi.product_id,  -- Added 'oi.' right here!
        AVG(r.rating) as avg_prod_rating
    FROM reviews r
    JOIN order_items oi ON r.order_id = oi.order_id
    GROUP BY oi.product_id -- And added 'oi.' here!
)
SELECT 
    CASE 
        WHEN pr.avg_prod_rating >= 4.0 THEN 'High Rated'
        WHEN pr.avg_prod_rating >= 3.0 THEN 'Mid Rated'
        ELSE 'Low Rated'
    END AS rating_category,
    COUNT(DISTINCT p.product_id) AS product_count,
    SUM(oi.unit_price * oi.quantity) AS total_revenue,
    ROUND(AVG(p.unit_price), 2) AS avg_unit_price
FROM products p
JOIN Product_Ratings pr ON p.product_id = pr.product_id
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY 1
ORDER BY total_revenue DESC;

-- Question 8: Top Seller Bonus Qualification
WITH Seller_Metrics AS (
    -- Calculate revenue and orders BEFORE joining reviews
    SELECT 
        seller_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(total_amount) AS total_revenue
    FROM orders
    WHERE order_date >= '2024-01-01' AND order_date <= '2024-12-31'
    GROUP BY seller_id
),
Seller_Ratings AS (
    -- Calculate average ratings separately
    SELECT 
        o.seller_id,
        AVG(r.rating) AS average_rating
    FROM orders o
    JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_date >= '2024-01-01' AND o.order_date <= '2024-12-31'
    GROUP BY o.seller_id
)
-- Bring them together safely
SELECT 
    s.seller_name,
    sm.total_orders,
    ROUND(sr.average_rating, 2) AS average_rating,
    sm.total_revenue
FROM sellers s
JOIN Seller_Metrics sm ON s.seller_id = sm.seller_id
JOIN Seller_Ratings sr ON s.seller_id = sr.seller_id
WHERE sm.total_orders >= 10 AND sr.average_rating >= 4.0
ORDER BY sm.total_revenue DESC
LIMIT 10;