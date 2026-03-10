SELECT store_id,COUNT(customer_id) FROM custome;
GROUP BY store_id
HAVING COUNT(customer_id) > 300;
