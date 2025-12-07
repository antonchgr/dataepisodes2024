
/* ============================
   SQL Server 2025 CES demo
   Change Event Streaming -> Azure Event Hubs (AMQP)
   ============================ */
/*
    USE cesdemo;
    EXEC sys.sp_disable_event_stream
    GO

    USE master;
    GO
    DROP DATABASE IF EXISTS cesdemo;
    GO
    CREATE DATABASE cesdemo;
    GO
*/

USE cesdemo;
GO

-- Enable preview features (required by CES on SQL Server 2025)
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO 
-- SET Recovery model FULL + initial full backup (recommended)
-- CES relies on the transaction log; FULL recovery is required. See CES FAQ.
ALTER DATABASE cesdemo SET RECOVERY FULL;
GO
BACKUP DATABASE cesdemo TO DISK = 'nul';
GO

-- Create Master key (required to store SAS securely)
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name ='##MS_DatabaseMasterKey##')
    DROP MASTER KEY;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '...';
GO

-- Database scoped credential with SAS (AMQP) - ensure '&' not '&amp;'
IF EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'cessas')
    DROP DATABASE SCOPED CREDENTIAL cessas;
GO
CREATE DATABASE SCOPED CREDENTIAL cessas
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
     SECRET = 'SharedAccessSignature sr=...&sig=...&se=...&skn=...';
GO

-- Create Customers Demo table
DROP TABLE IF EXISTS dbo.Customers;
GO
CREATE TABLE dbo.Customers(
    [custid]        int IDENTITY(1,1) NOT NULL,
    [companyname]   nvarchar(40)      NOT NULL,
    [contactname]   nvarchar(30)      NULL,
    [contacttitle]  nvarchar(30)      NULL,
    [vatnumber]     nvarchar(10)      NULL,
    [address]       nvarchar(80)      NULL,
    [city]          nvarchar(30)      NULL,
    [postalcode]    int               NULL,
    [region]        nvarchar(50)      NULL,
    [perfecture]    nvarchar(50)      NULL,
    [country]       nvarchar(15)      NULL,
    [phone]         nvarchar(16)      NULL,
    [email]         nvarchar(256)     NULL,
    CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED ([custid])
);
GO

-- Enable CES at DB level
EXEC sys.sp_enable_event_stream;  -- requires preview features enabled
GO
-- Check:
SELECT name, is_event_stream_enabled FROM sys.databases WHERE database_id = DB_ID();
GO
-- Disable CES at DB level
-- EXEC sys.sp_disable_event_stream
-- Check


-- Create event stream group -> Azure Event Hubs (AMQP)
EXEC sys.sp_create_event_stream_group
    @stream_group_name     = N'cesdemogroup',
    @destination_type      = N'AzureEventHubsAmqp',
    @destination_location  = N'xla-eh-sqldemo.servicebus.windows.net/cessql2025', -- namespace/eventhub
    @destination_credential= cessas,
    @max_message_size_kb   = 1024,
    @partition_key_scheme  = N'Table',        -- each table to a separate partition
    @encoding              = N'JSON';         -- optional (default JSON)
GO

-- Drop event stream group
-- EXEC sys.sp_drop_event_stream_group  @stream_group_name =  N'cesdemogroup'
-- GO

-- Check
EXEC sys.sp_help_change_feed_table_groups
GO

-- Add table to the stream group (payload options)
EXEC sys.sp_add_object_to_event_stream_group
    @stream_group_name      = N'cesdemogroup',
    @object_name            = N'dbo.Customers',
    @include_all_columns    = 0,  -- only changed columns in payload
    @include_old_values     = 1,  -- include previous values
    @include_old_lob_values = 0;  -- skip old LOB values unless needed
GO

-- Verify change feed table state (Active=4)
EXEC sys.sp_help_change_feed_table @source_schema = 'dbo', @source_name = 'Customers';
GO

select * from dbo.Customers
-- Generate changes to test CES publishing
INSERT INTO dbo.Customers(companyname) VALUES (N'c1');
UPDATE dbo.Customers SET companyname = N'c1-upd' WHERE custid = 1;
DELETE FROM dbo.Customers WHERE custid = 1;
GO

-- Monitor CES progress & errors
SELECT TOP (50) * 
FROM sys.dm_change_feed_log_scan_sessions
ORDER BY start_time DESC;        -- batch_processing_phase: expect 7 for publish/commit; check error_count
GO
SELECT TOP (50) *
FROM sys.dm_change_feed_errors
ORDER BY entry_time DESC;        -- any delivery/credential/network errors will show up here
GO
