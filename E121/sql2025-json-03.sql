USE [HellasGateV2]
GO

-- Create a JSON index over commonly used paths (Preview) 
-- CUSTERED INDEX REQUIRED
/* 
How JSON indexes are stored
The JSON index data, unlike traditional rowstore or columnstore indexes, 
is not actually stored in a separate index on the table. 
It gets an entry in sys.indexes, but the rows are actually stored in 
an “internal table” (type=IT in sys.objects) in the database, 
and SQL Server keeps that internal table updated transparently and atomically, 
just like a regular rowstore index. 
This is similar to how XML indexes and spatial indexes work.
*/

CREATE JSON INDEX jsidx_custromers_json
ON sales.Customers_json([address]);
GO

SELECT * FROM sys.json_indexes
SELECT * FROM sys.json_index_paths

-- run in DAC
USE HellasGateV2
GO
SELECT TOP (1000) *
FROM sys.json_index_706101556_1216000;
GO

SELECT * FROM sales.Customers_json
WHERE JSON_VALUE([address],'$.city') = 'Ρόδος';
GO

-- INDEX HINT REQUIRED
SELECT * FROM sales.Customers_json WITH(INDEX(jsidx_custromers_json)) --with(index(1216000))
WHERE JSON_VALUE([address],'$.city') = 'Ρόδος';
GO

/*
Msg 13681, Level 16, State 1, Line 54
A JSON index 'jsidx_custromers_json' already exists on column 'address' 
on table 'Customers_json', and multiple JSON indexes per column are not allowed.
*/
DROP INDEX IF EXISTS jsidx_custromers_json ON sales.Customers_json;
GO

CREATE JSON INDEX jsidx_custromers_json
ON sales.Customers_json([address])
FOR ('$.city','$.country');
GO

SELECT * FROM sales.Customers_json WITH(INDEX(jsidx_custromers_json))
WHERE JSON_VALUE([address],'$.city') = 'Ρόδος';
GO
