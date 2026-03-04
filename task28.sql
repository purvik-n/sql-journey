SELECT first_name,last_name
FROM customer AS c
WHERE EXISTS
(SELECT * FROM payment AS P
WHERE p.costomer_id =c.customer_id
AND amount > 11);
