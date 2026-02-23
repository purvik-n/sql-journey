-- Count employees in IT department
SELECT COUNT(*) AS it_employees
FROM employees
WHERE department = 'IT';
