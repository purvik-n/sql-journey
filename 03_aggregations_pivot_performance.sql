-- ============================================================
--  SQL Practice: Aggregations, Pivoting & Performance Tuning
--  Date   : 2026-03-16
--  Topics : GROUP BY extensions (ROLLUP, CUBE, GROUPING SETS),
--           conditional aggregation / pivot, FILTER clause,
--           indexes & EXPLAIN ANALYZE, query optimisation tips
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- SETUP: Sales schema
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(100),
    category     VARCHAR(50),
    unit_price   DECIMAL(10,2)
);

CREATE TABLE IF NOT EXISTS sales (
    sale_id    INT PRIMARY KEY,
    product_id INT,
    region     VARCHAR(50),
    salesperson VARCHAR(100),
    sale_date  DATE,
    quantity   INT,
    discount   DECIMAL(4,2)   -- e.g. 0.10 = 10 %
);

-- Seed products
INSERT INTO products VALUES
    (1,  'Laptop Pro',     'Electronics', 85000.00),
    (2,  'Wireless Mouse', 'Electronics',  2500.00),
    (3,  'Desk Chair',     'Furniture',   18000.00),
    (4,  'Standing Desk',  'Furniture',   35000.00),
    (5,  'Notebook Set',   'Stationery',    450.00),
    (6,  'Pen Pack',       'Stationery',    120.00),
    (7,  'Monitor 27"',    'Electronics', 32000.00),
    (8,  'Keyboard',       'Electronics',  4500.00);

-- Seed sales
INSERT INTO sales VALUES
    (1,  1, 'North', 'Aarav Shah',   '2026-01-08',  3, 0.05),
    (2,  2, 'North', 'Aarav Shah',   '2026-01-10', 15, 0.00),
    (3,  3, 'South', 'Bhavna Jain',  '2026-01-12',  5, 0.10),
    (4,  1, 'East',  'Chirag Mehta', '2026-01-20',  2, 0.00),
    (5,  7, 'West',  'Diya Patel',   '2026-01-25',  8, 0.08),
    (6,  5, 'North', 'Aarav Shah',   '2026-02-03', 50, 0.00),
    (7,  4, 'South', 'Bhavna Jain',  '2026-02-10',  3, 0.12),
    (8,  8, 'East',  'Chirag Mehta', '2026-02-14', 10, 0.05),
    (9,  2, 'West',  'Diya Patel',   '2026-02-20', 20, 0.00),
    (10, 7, 'North', 'Aarav Shah',   '2026-03-01',  4, 0.00),
    (11, 3, 'East',  'Chirag Mehta', '2026-03-05',  7, 0.07),
    (12, 6, 'South', 'Bhavna Jain',  '2026-03-08', 80, 0.00),
    (13, 1, 'West',  'Diya Patel',   '2026-03-11',  1, 0.15),
    (14, 8, 'North', 'Aarav Shah',   '2026-03-14',  6, 0.00),
    (15, 4, 'East',  'Chirag Mehta', '2026-03-16',  2, 0.10);

-- ─────────────────────────────────────────────────────────────
-- 1. Revenue calculation (with discount)
-- ─────────────────────────────────────────────────────────────
SELECT
    s.sale_id,
    p.product_name,
    s.region,
    s.salesperson,
    s.quantity,
    p.unit_price,
    s.discount,
    ROUND(p.unit_price * s.quantity * (1 - s.discount), 2) AS net_revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
ORDER BY net_revenue DESC;

-- ─────────────────────────────────────────────────────────────
-- 2. ROLLUP — subtotals & grand total (category → region)
-- ─────────────────────────────────────────────────────────────
SELECT
    p.category,
    s.region,
    SUM(ROUND(p.unit_price * s.quantity * (1 - s.discount), 2)) AS total_revenue,
    GROUPING(p.category) AS is_category_subtotal,
    GROUPING(s.region)   AS is_grand_total
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY ROLLUP(p.category, s.region)
ORDER BY p.category NULLS LAST, s.region NULLS LAST;

-- ─────────────────────────────────────────────────────────────
-- 3. CUBE — all combinations of grouping dimensions
--    (category, region, salesperson)
-- ─────────────────────────────────────────────────────────────
SELECT
    COALESCE(p.category,  '** ALL **') AS category,
    COALESCE(s.region,    '** ALL **') AS region,
    COALESCE(s.salesperson,'** ALL **') AS salesperson,
    SUM(ROUND(p.unit_price * s.quantity * (1 - s.discount), 2)) AS total_revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY CUBE(p.category, s.region, s.salesperson)
ORDER BY category, region, salesperson;

-- ─────────────────────────────────────────────────────────────
-- 4. GROUPING SETS — custom aggregation combos
--    (only category total, only region total, grand total)
-- ─────────────────────────────────────────────────────────────
SELECT
    p.category,
    s.region,
    SUM(ROUND(p.unit_price * s.quantity * (1 - s.discount), 2)) AS total_revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY GROUPING SETS (
    (p.category),
    (s.region),
    ()
)
ORDER BY p.category NULLS LAST, s.region NULLS LAST;

-- ─────────────────────────────────────────────────────────────
-- 5. Conditional aggregation (manual PIVOT)
--    Revenue per category for each month (Jan–Mar)
-- ─────────────────────────────────────────────────────────────
SELECT
    p.category,
    ROUND(SUM(CASE WHEN EXTRACT(MONTH FROM s.sale_date) = 1
                   THEN p.unit_price * s.quantity * (1 - s.discount) ELSE 0 END), 2) AS jan_revenue,
    ROUND(SUM(CASE WHEN EXTRACT(MONTH FROM s.sale_date) = 2
                   THEN p.unit_price * s.quantity * (1 - s.discount) ELSE 0 END), 2) AS feb_revenue,
    ROUND(SUM(CASE WHEN EXTRACT(MONTH FROM s.sale_date) = 3
                   THEN p.unit_price * s.quantity * (1 - s.discount) ELSE 0 END), 2) AS mar_revenue,
    ROUND(SUM(p.unit_price * s.quantity * (1 - s.discount)), 2)                       AS total_revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;

-- ─────────────────────────────────────────────────────────────
-- 6. FILTER clause (SQL:2003) — cleaner conditional aggregation
--    Average discount per region, split by Electronics vs others
-- ─────────────────────────────────────────────────────────────
SELECT
    s.region,
    ROUND(AVG(s.discount) FILTER (WHERE p.category = 'Electronics'), 4) AS avg_electronics_disc,
    ROUND(AVG(s.discount) FILTER (WHERE p.category <> 'Electronics'), 4) AS avg_other_disc,
    ROUND(AVG(s.discount), 4)                                             AS avg_overall_disc
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY s.region
ORDER BY s.region;

-- ─────────────────────────────────────────────────────────────
-- 7. HAVING with aggregates — regions where Electronics revenue
--    alone exceeds 100 000
-- ─────────────────────────────────────────────────────────────
SELECT
    s.region,
    ROUND(SUM(p.unit_price * s.quantity * (1 - s.discount)), 2) AS electronics_revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
WHERE p.category = 'Electronics'
GROUP BY s.region
HAVING SUM(p.unit_price * s.quantity * (1 - s.discount)) > 100000
ORDER BY electronics_revenue DESC;

-- ─────────────────────────────────────────────────────────────
-- 8. Indexes — understanding why they matter
-- ─────────────────────────────────────────────────────────────

-- Without indexes, a JOIN on product_id does a full sequential scan.
-- Add indexes to frequently joined / filtered columns:

-- Index on foreign key (very common miss!)
CREATE INDEX IF NOT EXISTS idx_sales_product_id  ON sales(product_id);
-- Index for date-range queries
CREATE INDEX IF NOT EXISTS idx_sales_date        ON sales(sale_date);
-- Composite index for reporting queries that filter region then category
CREATE INDEX IF NOT EXISTS idx_sales_region      ON sales(region);

-- Partial index — only index high-value sales (hypothetical, illustrative)
-- CREATE INDEX idx_high_value_sales ON sales(product_id) WHERE quantity > 10;

-- ─────────────────────────────────────────────────────────────
-- 9. EXPLAIN ANALYZE — read the query plan
--    (PostgreSQL syntax; adapt for your RDBMS)
-- ─────────────────────────────────────────────────────────────
EXPLAIN ANALYZE
SELECT
    p.category,
    s.region,
    SUM(p.unit_price * s.quantity * (1 - s.discount)) AS revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
WHERE s.sale_date BETWEEN '2026-01-01' AND '2026-03-31'
GROUP BY p.category, s.region
ORDER BY revenue DESC;

/*
  HOW TO READ THE PLAN:
  ─────────────────────
  • Seq Scan        → full table scan; add an index if hitting large tables
  • Index Scan      → index used; fast for selective queries
  • Hash Join       → builds a hash-table for smaller side; good for large sets
  • Nested Loop     → great when outer set is tiny; bad when both sides are large
  • rows=N (actual) → if actual >> estimated, statistics are stale → run ANALYZE
  • cost=X..Y       → startup cost .. total cost; lower is better
  • Rows Removed by Filter → high number = index on that column may help
*/

-- Refresh statistics after bulk inserts:
-- ANALYZE sales;
-- ANALYZE products;

-- ─────────────────────────────────────────────────────────────
-- 10. Performance tuning checklist (as comments)
-- ─────────────────────────────────────────────────────────────
/*
  ✅ SELECT only needed columns — avoid SELECT *
  ✅ Filter early — push WHERE conditions into CTEs/subqueries
  ✅ Avoid functions on indexed columns in WHERE
       BAD : WHERE YEAR(sale_date) = 2026
       GOOD: WHERE sale_date BETWEEN '2026-01-01' AND '2026-12-31'
  ✅ Prefer JOINs over correlated subqueries when tables are large
  ✅ Use EXISTS instead of IN when subquery result set is large
  ✅ Add indexes on FK columns and columns used in ORDER BY / GROUP BY
  ✅ Use LIMIT for pagination; use keyset pagination for deep pages
  ✅ Run EXPLAIN ANALYZE before and after optimisation to compare plans
  ✅ Partition large tables by date/region if queries always filter on them
  ✅ Materialise frequently-reused CTEs with MATERIALIZED keyword (Postgres 12+)
       WITH expensive_cte AS MATERIALIZED ( ... )
*/

-- ─────────────────────────────────────────────────────────────
-- 11. Self-challenge: Rank salesperson by revenue inside each
--     category and flag the top performer per category
-- ─────────────────────────────────────────────────────────────
WITH rep_revenue AS (
    SELECT
        p.category,
        s.salesperson,
        ROUND(SUM(p.unit_price * s.quantity * (1 - s.discount)), 2) AS revenue
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY p.category, s.salesperson
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
    FROM rep_revenue
)
SELECT
    category,
    salesperson,
    revenue,
    rnk,
    CASE WHEN rnk = 1 THEN '🏆 Top Performer' ELSE '' END AS badge
FROM ranked
ORDER BY category, rnk;
