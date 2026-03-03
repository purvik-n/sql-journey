SELECT COUNT(*) AS payments_on_monday
FROM payment
WHERE EXTRACT(DOW FROM payment_date) = 1;
