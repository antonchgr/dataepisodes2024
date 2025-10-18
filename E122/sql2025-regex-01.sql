USE HellasGateV2;
GO

-- REGEXP_COUNT: Count consecutive 's' characters in city names
SELECT custid, city,
       REGEXP_COUNT(city, '[σΣ]{2,}') AS SequenceCount
FROM sales.Customers
WHERE REGEXP_COUNT(city, '[σΣ]{2,}') > 0
ORDER BY SequenceCount DESC;



-- REGEXP_COUNT with multi-line mode flag
SELECT REGEXP_COUNT('Line1
Line2
Line3
Line4', '$', 1, 'm') AS NewLineCount;



-- REGEXP_INSTR: Find position of 'New' in city names
SELECT City,
       REGEXP_INSTR(City, 'Νέα') AS StringLocation
FROM sales.Customers
WHERE REGEXP_INSTR(City, 'Νέα') > 0;



-- REGEXP_LIKE: Match customer names containing 
SELECT email
FROM sales.Customers
WHERE REGEXP_LIKE(email, '@chatzipavlis');




-- REGEXP_LIKE: Match primary contacts starting with 'A' and ending with 'a'
SELECT custid, contactname
FROM sales.Customers
WHERE REGEXP_LIKE(contactname, '^Α.*α$');




-- REGEXP_REPLACE: Replace 'Νέα' with 'Παλαιά' in city names
SELECT City,
       REGEXP_REPLACE(City, 'Νέα', 'Παλαιά') AS NewCityName
FROM sales.Customers
WHERE REGEXP_COUNT(City, 'Νέα') > 0;




-- REGEXP_REPLACE: Replace second occurrence of 'Νέα' or 'Παλαιά' with empty ''
SELECT City,
       TRIM(REGEXP_REPLACE(City, 'Νέα|Παλαιά', '', 1, 1, 'i')) AS ΝewCityName
FROM sales.Customers
WHERE REGEXP_REPLACE(City, 'Νέα|Παλαιά', '', 1, 1, 'i') <> City;




-- REGEXP_SUBSTR: Extract text inside parentheses from customer names
SELECT city,
       REGEXP_SUBSTR(city, '\([^)]+\)') AS ExtractedOfficeLocation,
       REGEXP_REPLACE(REGEXP_SUBSTR(city, '\([^)]+\)'), '[()]', '') AS OfficeLocation
FROM sales.Customers
WHERE REGEXP_LIKE(city, '\([^)]+\)')




-- REGEXP_SUBSTR: Extract domain name from email address
SELECT REGEXP_SUBSTR(email, '@(.+)$', 1, 1, 'i', 1) AS DOMAIN
FROM sales.Customers;




-- REGEXP_MATCHES: Detailed match info for cities with multiple 'σσ'
SELECT custid, city, RegexMatchData.*
FROM sales.Customers
CROSS APPLY REGEXP_MATCHES(city, '[σΣ]{2,}') AS RegexMatchData
WHERE REGEXP_COUNT(city, '[σΣ]{2,}') > 1
ORDER BY city;




-- REGEXP_SPLIT_TO_TABLE: Split city names on double 'σσ'
SELECT custid, city, RegexSplitData.*
FROM sales.Customers
CROSS APPLY REGEXP_SPLIT_TO_TABLE(city, '[σΣ]{2,}') AS RegexSplitData
WHERE REGEXP_COUNT(city, '[σΣ]{2,}') > 1
ORDER BY city;

