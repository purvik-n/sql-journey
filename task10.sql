SELECT COUNT(customer_id), staff_id FROM payment
GROUP BY staff_id
ORDER BY staff_id;
