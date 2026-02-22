SELECT * FROM customer
WHERE first_name NOT LIKE '%her%' AND last_name NOT like 'B%'
ORDER BY last_name;
