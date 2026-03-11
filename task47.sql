SELECT cd.bookings.starttime,cd.facilities.name
FROM cd.facilities
INNER JOIN cd.bookings
ON cd.facilities.facid = cd.bookings.facid
WHERE cd.facilities.name IN ('0','1')
AND cd.bookings.starttime >= '2012-09-21'
AND cd.bookings.starttime < '2021-09-22';
