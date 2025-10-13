USE [HellasGateV2]
GO

-- add data to table
SET IDENTITY_INSERT sales.Customers_json on;
INSERT INTO sales.Customers_json([custid], [companyname], [contactname], [contacttitle], [vatnumber], [address], [phone], [email])
SELECT [custid]
      ,[companyname]
      ,[contactname]
      ,[contacttitle]
      ,[vatnumber]
      ,JSON_OBJECT (
        'street':[address],
        'city':[city],
        'postalcode':[postalcode],
        'region':[region],
        'pefrecture':[perfecture],
        'country':[country]
        ) as [adderess]
      ,[phone]
      ,[email]
FROM [sales].[Customers];
SET IDENTITY_INSERT sales.Customers_json off;
GO

SELECT TOP(100) * 
FROM sales.Customers_json
GO