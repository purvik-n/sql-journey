SELECT customer_id, COUNT(*) FROM payment
GROUP BY customer_id
HAVING COUNT(customer_id) >= 40;
