SELECT facid,SUM(slots) AS total_slots
FROM cd.bookings
WHERE starttime >= '2012-09-01' AND 
starttime <= '2012-10-01'
GROUP BY facid ORDER BY SUM(slots);
