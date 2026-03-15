-- ============================================================
--  SQL Practice: CTEs, Subqueries & Advanced Joins
--  Date   : 2026-03-16
--  Topics : Recursive CTEs, multiple CTEs, correlated
--           subqueries, EXISTS / NOT EXISTS, LATERAL joins,
--           SELF joins, CROSS JOIN, FULL OUTER JOIN
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- SETUP: Employee / Department hierarchy
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS departments (
    dept_id   INT PRIMARY KEY,
    dept_name VARCHAR(100),
    parent_id INT  -- NULL means top-level
);

CREATE TABLE IF NOT EXISTS employees (
    emp_id     INT PRIMARY KEY,
    emp_name   VARCHAR(100),
    dept_id    INT,
    manager_id INT,          -- self-referential
    salary     DECIMAL(10,2),
    hire_date  DATE
);

CREATE TABLE IF NOT EXISTS projects (
    project_id   INT PRIMARY KEY,
    project_name VARCHAR(100),
    dept_id      INT,
    budget       DECIMAL(12,2)
);

CREATE TABLE IF NOT EXISTS emp_projects (
    emp_id     INT,
    project_id INT,
    role       VARCHAR(50),
    PRIMARY KEY (emp_id, project_id)
);

-- Seed departments (two-level hierarchy)
INSERT INTO departments VALUES
    (1, 'Company HQ',        NULL),
    (2, 'Engineering',       1),
    (3, 'Product',           1),
    (4, 'Backend Team',      2),
    (5, 'Frontend Team',     2),
    (6, 'Data Team',         2),
    (7, 'Design Team',       3);

-- Seed employees
INSERT INTO employees VALUES
    (1,  'Riya Desai',    2,  NULL, 180000.00, '2020-01-15'),
    (2,  'Arjun Rao',     4,  1,    120000.00, '2021-03-01'),
    (3,  'Meera Joshi',   4,  1,    115000.00, '2021-06-15'),
    (4,  'Karan Malhotra',5,  1,     98000.00, '2022-01-10'),
    (5,  'Sneha Iyer',    5,  1,     95000.00, '2022-05-20'),
    (6,  'Rohit Gupta',   6,  1,    130000.00, '2020-09-01'),
    (7,  'Priya Singh',   6,  6,    110000.00, '2023-02-01'),
    (8,  'Aditya Verma',  3,  NULL, 160000.00, '2019-07-15'),
    (9,  'Nisha Kapoor',  7,  8,     90000.00, '2023-05-10'),
    (10, 'Sam Thomas',    7,  8,     88000.00, '2023-08-01');

-- Seed projects
INSERT INTO projects VALUES
    (1, 'API Revamp',      4, 500000.00),
    (2, 'Mobile App',      5, 750000.00),
    (3, 'Data Pipeline',   6, 300000.00),
    (4, 'Design System',   7, 200000.00),
    (5, 'ML Platform',     6, 900000.00);

-- Seed emp_projects
INSERT INTO emp_projects VALUES
    (2, 1, 'Lead'),
    (3, 1, 'Developer'),
    (4, 2, 'Lead'),
    (5, 2, 'Developer'),
    (6, 3, 'Lead'),
    (6, 5, 'Architect'),
    (7, 3, 'Developer'),
    (7, 5, 'Developer'),
    (9, 4, 'Designer'),
    (10,4, 'Designer');

-- ─────────────────────────────────────────────────────────────
-- 1. Recursive CTE — traverse the full org chart
--    Output: every employee with their level in the hierarchy
-- ─────────────────────────────────────────────────────────────
WITH RECURSIVE org_chart AS (
    -- Anchor: top-level employees (no manager)
    SELECT
        emp_id,
        emp_name,
        manager_id,
        1                       AS org_level,
        CAST(emp_name AS VARCHAR(500)) AS path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive member
    SELECT
        e.emp_id,
        e.emp_name,
        e.manager_id,
        oc.org_level + 1,
        CONCAT(oc.path, ' → ', e.emp_name)
    FROM employees e
    JOIN org_chart oc ON e.manager_id = oc.emp_id
)
SELECT
    emp_id,
    emp_name,
    org_level,
    path
FROM org_chart
ORDER BY org_level, emp_name;

-- ─────────────────────────────────────────────────────────────
-- 2. Recursive CTE — expand department hierarchy into a tree
-- ─────────────────────────────────────────────────────────────
WITH RECURSIVE dept_tree AS (
    SELECT dept_id, dept_name, parent_id, 0 AS depth,
           CAST(dept_name AS VARCHAR(500)) AS full_path
    FROM   departments
    WHERE  parent_id IS NULL

    UNION ALL

    SELECT d.dept_id, d.dept_name, d.parent_id, dt.depth + 1,
           CONCAT(dt.full_path, ' > ', d.dept_name)
    FROM   departments d
    JOIN   dept_tree   dt ON d.parent_id = dt.dept_id
)
SELECT dept_id, REPEAT('  ', depth) || dept_name AS indented_name, full_path
FROM   dept_tree
ORDER BY full_path;

-- ─────────────────────────────────────────────────────────────
-- 3. Multiple CTEs — salary bands + department stats
-- ─────────────────────────────────────────────────────────────
WITH dept_stats AS (
    SELECT
        dept_id,
        ROUND(AVG(salary), 2)  AS avg_salary,
        MAX(salary)            AS max_salary,
        COUNT(*)               AS headcount
    FROM employees
    GROUP BY dept_id
),
banded AS (
    SELECT
        e.emp_id,
        e.emp_name,
        e.salary,
        d.dept_name,
        ds.avg_salary,
        CASE
            WHEN e.salary >= ds.avg_salary * 1.2 THEN 'High'
            WHEN e.salary >= ds.avg_salary * 0.8 THEN 'Average'
            ELSE                                       'Low'
        END AS salary_band
    FROM employees e
    JOIN departments d  ON e.dept_id  = d.dept_id
    JOIN dept_stats  ds ON e.dept_id  = ds.dept_id
)
SELECT *
FROM   banded
ORDER BY dept_name, salary DESC;

-- ─────────────────────────────────────────────────────────────
-- 4. Correlated Subquery — employees earning above their
--    own department's average salary
-- ─────────────────────────────────────────────────────────────
SELECT
    e.emp_name,
    d.dept_name,
    e.salary,
    (SELECT ROUND(AVG(e2.salary),2) FROM employees e2 WHERE e2.dept_id = e.dept_id) AS dept_avg
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > (
    SELECT AVG(e3.salary) FROM employees e3 WHERE e3.dept_id = e.dept_id
)
ORDER BY e.salary DESC;

-- ─────────────────────────────────────────────────────────────
-- 5. EXISTS vs NOT EXISTS
--    a) Employees assigned to at least one project
--    b) Employees with NO project assignment
-- ─────────────────────────────────────────────────────────────
-- 5a
SELECT emp_name
FROM   employees e
WHERE  EXISTS (
    SELECT 1 FROM emp_projects ep WHERE ep.emp_id = e.emp_id
);

-- 5b
SELECT emp_name
FROM   employees e
WHERE  NOT EXISTS (
    SELECT 1 FROM emp_projects ep WHERE ep.emp_id = e.emp_id
);

-- ─────────────────────────────────────────────────────────────
-- 6. SELF JOIN — find all manager–report pairs
-- ─────────────────────────────────────────────────────────────
SELECT
    m.emp_name AS manager,
    r.emp_name AS report,
    r.salary,
    d.dept_name
FROM employees r
JOIN employees    m ON r.manager_id = m.emp_id
JOIN departments  d ON r.dept_id    = d.dept_id
ORDER BY manager, report;

-- ─────────────────────────────────────────────────────────────
-- 7. FULL OUTER JOIN — projects with no assigned employees
--    AND employees with no project assignment
-- ─────────────────────────────────────────────────────────────
SELECT
    e.emp_name,
    p.project_name
FROM employees   e
FULL OUTER JOIN emp_projects ep ON e.emp_id     = ep.emp_id
FULL OUTER JOIN projects      p ON ep.project_id = p.project_id
WHERE e.emp_id IS NULL OR p.project_id IS NULL;

-- ─────────────────────────────────────────────────────────────
-- 8. CROSS JOIN — generate a salary × department grid
--    (useful for building planning matrices)
-- ─────────────────────────────────────────────────────────────
SELECT
    d.dept_name,
    sb.band,
    COUNT(e.emp_id)        AS headcount,
    SUM(e.salary)          AS total_payroll
FROM departments d
CROSS JOIN (VALUES ('High'), ('Average'), ('Low')) AS sb(band)
LEFT JOIN (
    WITH dept_stats AS (
        SELECT dept_id, AVG(salary) AS avg_salary
        FROM   employees
        GROUP BY dept_id
    )
    SELECT
        e.emp_id, e.dept_id,
        CASE
            WHEN e.salary >= ds.avg_salary * 1.2 THEN 'High'
            WHEN e.salary >= ds.avg_salary * 0.8 THEN 'Average'
            ELSE 'Low'
        END AS band,
        e.salary
    FROM employees e
    JOIN dept_stats ds ON e.dept_id = ds.dept_id
) e ON d.dept_id = e.dept_id AND sb.band = e.band
GROUP BY d.dept_name, sb.band
ORDER BY d.dept_name, sb.band;

-- ─────────────────────────────────────────────────────────────
-- 9. Challenge: Find departments where total project budget
--    exceeds the total salary cost of all employees in that dept
-- ─────────────────────────────────────────────────────────────
WITH dept_payroll AS (
    SELECT dept_id, SUM(salary) AS total_salary
    FROM   employees
    GROUP BY dept_id
),
dept_budget AS (
    SELECT dept_id, SUM(budget) AS total_budget
    FROM   projects
    GROUP BY dept_id
)
SELECT
    d.dept_name,
    COALESCE(dp.total_salary, 0)  AS total_salary,
    COALESCE(db.total_budget, 0)  AS total_budget,
    COALESCE(db.total_budget, 0) - COALESCE(dp.total_salary, 0) AS surplus
FROM departments  d
LEFT JOIN dept_payroll dp ON d.dept_id = dp.dept_id
LEFT JOIN dept_budget  db ON d.dept_id = db.dept_id
WHERE COALESCE(db.total_budget, 0) > COALESCE(dp.total_salary, 0)
ORDER BY surplus DESC;
