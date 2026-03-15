-- ============================================================
--  SQL Practice: Window Functions (Intermediate / Advanced)
--  Date   : 2026-03-16
--  Topics : ROW_NUMBER, RANK, DENSE_RANK, NTILE,
--           LAG, LEAD, FIRST_VALUE, LAST_VALUE,
--           Running totals, Moving averages
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- SETUP: Sample schema (e-commerce orders)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
    customer_id   INT PRIMARY KEY,
    customer_name VARCHAR(100),
    region        VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id    INT PRIMARY KEY,
    customer_id INT,
    order_date  DATE,
    amount      DECIMAL(10, 2),
    category    VARCHAR(50)
);

-- Seed data
INSERT INTO customers VALUES
    (1, 'Alice Sharma',   'North'),
    (2, 'Bob Mehta',      'South'),
    (3, 'Carol Patel',    'East'),
    (4, 'David Nair',     'West'),
    (5, 'Eva Krishnan',   'North');

INSERT INTO orders VALUES
    (101, 1, '2026-01-05',  1200.00, 'Electronics'),
    (102, 2, '2026-01-10',   450.00, 'Clothing'),
    (103, 1, '2026-01-15',  3400.00, 'Electronics'),
    (104, 3, '2026-01-20',   780.00, 'Groceries'),
    (105, 2, '2026-02-01',  2100.00, 'Electronics'),
    (106, 4, '2026-02-05',   310.00, 'Clothing'),
    (107, 5, '2026-02-10',  5600.00, 'Electronics'),
    (108, 3, '2026-02-15',   920.00, 'Groceries'),
    (109, 1, '2026-03-01',  1750.00, 'Clothing'),
    (110, 4, '2026-03-10',  4400.00, 'Electronics'),
    (111, 5, '2026-03-12',   660.00, 'Groceries'),
    (112, 2, '2026-03-15',  3200.00, 'Electronics');

-- ─────────────────────────────────────────────────────────────
-- 1. ROW_NUMBER, RANK, DENSE_RANK
--    Assign ranks to orders per customer by descending amount
-- ─────────────────────────────────────────────────────────────
SELECT
    o.order_id,
    c.customer_name,
    o.amount,
    ROW_NUMBER()  OVER (PARTITION BY o.customer_id ORDER BY o.amount DESC) AS row_num,
    RANK()        OVER (PARTITION BY o.customer_id ORDER BY o.amount DESC) AS rnk,
    DENSE_RANK()  OVER (PARTITION BY o.customer_id ORDER BY o.amount DESC) AS dense_rnk
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id;

-- ─────────────────────────────────────────────────────────────
-- 2. Fetch only the TOP-1 order per customer (highest amount)
--    Use a CTE + ROW_NUMBER pattern
-- ─────────────────────────────────────────────────────────────
WITH ranked_orders AS (
    SELECT
        o.*,
        c.customer_name,
        ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.amount DESC) AS rn
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
)
SELECT order_id, customer_name, order_date, amount, category
FROM   ranked_orders
WHERE  rn = 1
ORDER BY amount DESC;

-- ─────────────────────────────────────────────────────────────
-- 3. NTILE — Bucket customers into spend quartiles
-- ─────────────────────────────────────────────────────────────
WITH customer_spend AS (
    SELECT
        customer_id,
        SUM(amount) AS total_spend
    FROM orders
    GROUP BY customer_id
)
SELECT
    c.customer_name,
    cs.total_spend,
    NTILE(4) OVER (ORDER BY cs.total_spend DESC) AS quartile
FROM customer_spend cs
JOIN customers c ON cs.customer_id = c.customer_id;

-- ─────────────────────────────────────────────────────────────
-- 4. LAG & LEAD — Compare each order amount to the previous
--    and next order (within the same customer, by date)
-- ─────────────────────────────────────────────────────────────
SELECT
    o.order_id,
    c.customer_name,
    o.order_date,
    o.amount,
    LAG(o.amount,  1, 0) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS prev_amount,
    LEAD(o.amount, 1, 0) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS next_amount,
    o.amount - LAG(o.amount, 1, 0) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS change_from_prev
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
ORDER BY c.customer_name, o.order_date;

-- ─────────────────────────────────────────────────────────────
-- 5. Running Total & Moving Average (3-order window)
-- ─────────────────────────────────────────────────────────────
SELECT
    order_id,
    order_date,
    amount,
    SUM(amount)  OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
    ROUND(
        AVG(amount) OVER (ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2
    )                                                                                        AS moving_avg_3
FROM orders
ORDER BY order_date;

-- ─────────────────────────────────────────────────────────────
-- 6. FIRST_VALUE & LAST_VALUE within each category
--    (cheapest and most expensive order per category)
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT
    category,
    FIRST_VALUE(amount) OVER (
        PARTITION BY category ORDER BY amount ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS min_order_amount,
    LAST_VALUE(amount)  OVER (
        PARTITION BY category ORDER BY amount ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS max_order_amount
FROM orders
ORDER BY category;

-- ─────────────────────────────────────────────────────────────
-- 7. Cumulative % of total revenue per region
-- ─────────────────────────────────────────────────────────────
WITH region_revenue AS (
    SELECT
        c.region,
        SUM(o.amount) AS revenue
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.region
)
SELECT
    region,
    revenue,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)           AS pct_of_total,
    ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
          / SUM(revenue) OVER (), 2)                           AS cumulative_pct
FROM region_revenue
ORDER BY revenue DESC;

-- ─────────────────────────────────────────────────────────────
-- 8. Self-challenge: Find customers whose latest order amount
--    is strictly greater than their very first order amount
-- ─────────────────────────────────────────────────────────────
WITH order_bounds AS (
    SELECT
        customer_id,
        FIRST_VALUE(amount) OVER (PARTITION BY customer_id ORDER BY order_date
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_amt,
        LAST_VALUE(amount)  OVER (PARTITION BY customer_id ORDER BY order_date
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_amt
    FROM orders
)
SELECT DISTINCT
    c.customer_name,
    ob.first_amt,
    ob.last_amt,
    ob.last_amt - ob.first_amt AS growth
FROM order_bounds ob
JOIN customers c ON ob.customer_id = c.customer_id
WHERE ob.last_amt > ob.first_amt
ORDER BY growth DESC;
