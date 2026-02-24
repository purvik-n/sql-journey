SELECT customer_id,staff_id, SUM(amount) FROM payment
WHERE staff_id != 1
GROUP BY customer_id,staff_id
HAVING SUM(amount) >= 100;
