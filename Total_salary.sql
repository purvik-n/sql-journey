-- Total salary of IT department
SELECT SUM(salary) AS it_total_salary
FROM employees
WHERE department = 'IT';
