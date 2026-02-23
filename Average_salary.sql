-- Average salary in HR department
SELECT AVG(salary) AS hr_avg_salary
FROM employees
WHERE department = 'HR';
