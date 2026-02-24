SELECT rating,AVG(replacement_cost) FROM film
GROUP BY rating
ORDER BY rating ;
