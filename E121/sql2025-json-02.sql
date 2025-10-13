USE [HellasGateV2]
GO

-- Basic reads
SELECT 
    custid
,   JSON_VALUE([address],'$.street') as StreetName
,   JSON_VALUE([address],'$.city') as CityName
,   JSON_VALUE([address],'$.postalcode') as PostCode
,   JSON_VALUE([address],'$.region') as Region
,   JSON_VALUE([address],'$.pefrecture') as Pefrecture
,   JSON_VALUE([address],'$.country') as Country
FROM sales.Customers_json

-- Filtering
SELECT * FROM sales.Customers_json
WHERE JSON_VALUE([address],'$.city') = 'Ρόδος';
GO

-- Filtering with ANSI array wildcard in path (preview)
SELECT * FROM sales.Customers_json
WHERE JSON_PATH_EXISTS([address],'$.city') = 1;
GO

SELECT * FROM sales.Customers_json
WHERE JSON_VALUE([address],'$.postalcode' returning int ) between 70000 and 79999;
GO

SELECT * FROM sales.Customers_json
WHERE JSON_CONTAINS([address],'Ρόδος', '$.city') = 1;
GO

-- JSON_ARRAYAGG
SELECT 
    JSON_ARRAYAGG(contacttitle)
FROM sales.Customers_json
WHERE JSON_CONTAINS([address],'Ρόδος', '$.city') = 1;
GO
