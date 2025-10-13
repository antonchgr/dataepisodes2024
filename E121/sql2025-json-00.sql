USE [HellasGateV2]
GO

-- enable preview features if required in your RC build
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;  -- see release notes for RC gating

-- drop existing demo table
DROP TABLE IF EXISTS [sales].[Customers_json];
GO

-- create table
CREATE TABLE [sales].[Customers_json](
	[custid] [int] IDENTITY(1,1) NOT NULL,
	[companyname] [nvarchar](40) NOT NULL,
	[contactname] [nvarchar](30) NOT NULL,
	[contacttitle] [nvarchar](30) NOT NULL,
	[vatnumber] [nvarchar](10) NOT NULL,
	[address] json NOT NULL,
	[phone] [nvarchar](16) NOT NULL,
	[email] [nvarchar](256) NULL,
 CONSTRAINT [PK_Customers_json] PRIMARY KEY CLUSTERED 
(
	[custid] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
	   ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
	   ) ON [SECONDARY]
) ON [SECONDARY]
GO

