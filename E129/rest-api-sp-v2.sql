
CREATE OR ALTER PROCEDURE dbo.ConnectPowerBIExecuteDaxQuery
(
    @TenantId           nvarchar(64),                 -- GUID του tenant
    @ClientId           nvarchar(100),                -- App (client) ID
    @ClientSecret       nvarchar(max),                -- Client secret (VALUE)
    @WorkspaceId        nvarchar(36) = NULL,          -- NULL/'' => myorg
    @DatasetId          nvarchar(36),                 -- GUID dataset
    @Dax                nvarchar(max),                -- MUST: EVALUATE table expression (ή { scalar })
    @IncludeNulls       bit           = 1,            -- serializerSettings.includeNulls
    @ReturnRawResponse  bit           = 0             -- 1 => returns raw JSON
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        /* 1) Receive access token (client_credentials, scope = /.default for Power BI) */
        DECLARE @TokenUrl nvarchar(1000);
        SET @TokenUrl = N'https://login.microsoftonline.com/' + @TenantId + N'/oauth2/v2.0/token';

        -- Basic URL-encoding for unsafe charsw in secret (+, &, %, =)
        DECLARE @ClientSecretEnc nvarchar(max);
        SET @ClientSecretEnc =
              REPLACE(REPLACE(REPLACE(REPLACE(@ClientSecret, N'%', N'%25'),
                                      N'+', N'%2B'),
                              N'&', N'%26'),
                      N'=', N'%3D');

        DECLARE @Body nvarchar(max);
        SET @Body =
              N'client_id='      + @ClientId
            + N'&client_secret=' + @ClientSecretEnc
            + N'&scope='         + N'https%3A%2F%2Fanalysis.windows.net%2Fpowerbi%2Fapi%2F.default'
            + N'&grant_type=client_credentials';

        DECLARE @TokenResp nvarchar(max), @rc int;
        EXEC @rc = sys.sp_invoke_external_rest_endpoint
             @url      = @TokenUrl,
             @method   = N'POST',
             @headers  = N'{"Content-Type":"application/x-www-form-urlencoded"}',
             @payload  = @Body,
             @timeout  = 30,
             @response = @TokenResp OUTPUT;

        IF @rc <> 0 OR @TokenResp IS NULL
            THROW 50020, 'Failed to acquire token', 1;

        DECLARE @AccessToken nvarchar(max);
        SET @AccessToken = JSON_VALUE(@TokenResp, '$.result.access_token');

        IF @AccessToken IS NULL
        BEGIN
            DECLARE @err  nvarchar(200) = JSON_VALUE(@TokenResp, '$.result.error');
            DECLARE @errd nvarchar(max) = JSON_VALUE(@TokenResp, '$.result.error_description');
            DECLARE @throwMsgTok nvarchar(2048) =
                LEFT(N'No access_token in response. error=' + ISNULL(@err,N'') + N' desc=' + ISNULL(@errd,N''), 2048);
            ;THROW 50021, @throwMsgTok, 1;
        END

        /* 2) Endpoint URL for ExecuteQueries */
        DECLARE @Endpoint nvarchar(2000);
        IF @WorkspaceId IS NULL OR @WorkspaceId = N''
            SET @Endpoint = N'https://api.powerbi.com/v1.0/myorg/datasets/' + @DatasetId + N'/executeQueries';
        ELSE
            SET @Endpoint = N'https://api.powerbi.com/v1.0/myorg/groups/' + @WorkspaceId + N'/datasets/' + @DatasetId + N'/executeQueries';

        /* 3) Master Key (if not exists) */
        IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
            CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'LONg_Pa$$_w0rd!';  -- demo, change it

        /* 4) Create/Recreate credential with Authorization header (literal SECRET) */
        IF EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name = N'https://api.powerbi.com')
            DROP DATABASE SCOPED CREDENTIAL [https://api.powerbi.com];

        DECLARE @Secret nvarchar(max);
        SET @Secret = N'{"Authorization":"Bearer ' + @AccessToken + N'"}';

        DECLARE @sqlCred nvarchar(max);
        SET @sqlCred =
            N'CREATE DATABASE SCOPED CREDENTIAL [https://api.powerbi.com] '
          + N'WITH IDENTITY = ''HTTPEndpointHeaders'', SECRET = ''' 
          + REPLACE(@Secret, '''', '''''') + N'''';
        EXEC (@sqlCred);

        /* 5) DAX payload —  STRING_ESCAPE for safe JSON escaping */
        DECLARE @DaxEsc nvarchar(max);
        SET @DaxEsc = STRING_ESCAPE(@Dax, 'json');  

        DECLARE @Payload nvarchar(max);
        SET @Payload =
            N'{"queries":[{"query":"' + @DaxEsc + N'"}],"serializerSettings":{"includeNulls":' +
            CASE WHEN @IncludeNulls=1 THEN N'true' ELSE N'false' END + N'}}';

        IF ISJSON(@Payload) <> 1
            THROW 50023, 'Payload is not valid JSON', 1;

        /* 6) ExecuteQueries call */
        DECLARE @ExecResp nvarchar(max);
        EXEC @rc = sys.sp_invoke_external_rest_endpoint
             @url        = @Endpoint,
             @method     = N'POST',
             @headers    = N'{"Content-Type":"application/json"}',
             @payload    = @Payload,
             @credential = [https://api.powerbi.com],
             @timeout    = 60,
             @response   = @ExecResp OUTPUT;

        IF @rc <> 0 OR @ExecResp IS NULL
            THROW 50022, 'ExecuteQueries call failed', 1;

        /* 7) if API returns JSON error, display it (<= 2048) */
        IF JSON_VALUE(@ExecResp, '$.error.code') IS NOT NULL
        BEGIN
            DECLARE @pbicode nvarchar(200) = JSON_VALUE(@ExecResp, '$.error.code');
            DECLARE @pbimsg  nvarchar(max) =
                COALESCE(
                    JSON_VALUE(@ExecResp, '$.error.pbi.error.details[0].detail.value'),
                    JSON_VALUE(@ExecResp, '$.error.message'),
                    JSON_VALUE(@ExecResp, '$.error.pbi.error.details[0].value'),
                    JSON_VALUE(@ExecResp, '$.error.pbi.error.details[0].detail')
                );

            DECLARE @throwMsg nvarchar(2048) = LEFT(COALESCE(@pbimsg, @pbicode, N'ExecuteQueries error'), 2048);
            ;THROW 50024, @throwMsg, 1;
        END

        /* 8) Return results */
        IF @ReturnRawResponse = 1
        BEGIN
            SELECT JSON_QUERY(@ExecResp, '$.result') AS PowerBI_ResultJson;
            RETURN 0;
        END

        /* 9) Find keys from 1st list and dynamic SELECT (tabular output) */
        IF OBJECT_ID('tempdb..#keys') IS NOT NULL DROP TABLE #keys;
        CREATE TABLE #keys(colname sysname, jsonkey nvarchar(400));

        INSERT INTO #keys(colname, jsonkey)
        SELECT REPLACE(REPLACE([key], '[', '_'), ']', '_') AS colname,
               [key] AS jsonkey
        FROM OPENJSON(@ExecResp, '$.result.results[0].tables[0].rows[0]');

        IF NOT EXISTS (SELECT 1 FROM #keys)
        BEGIN
            RAISERROR(N'No results found from ExecuteQueries.', 16, 1);
            RETURN;
        END

        DECLARE @selectList nvarchar(max);
        SET @selectList = N'';

        SELECT @selectList =
               ISNULL(@selectList, N'')
               + N'JSON_VALUE(j.value, ''$."'
               + REPLACE(jsonkey, '"', '\"')
               + N'"'') AS [' + colname + N'],'
        FROM #keys
        ORDER BY jsonkey;

        -- cut last comma
        SET @selectList = LEFT(@selectList, LEN(@selectList)-1);

        DECLARE @sqlSelect nvarchar(max);
        SET @sqlSelect =
            N'SELECT ' + @selectList + N'
              FROM OPENJSON(@R, ''$.result.results[0].tables[0].rows'') AS j;';

        EXEC sp_executesql @sqlSelect, N'@R nvarchar(max)', @R = @ExecResp;

        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(2048);
        SET @msg = 'Error ' + CAST(ERROR_NUMBER() AS nvarchar(10))
                 + ' (state ' + CAST(ERROR_STATE() AS nvarchar(10)) + '): '
                 + ERROR_MESSAGE();
        ;THROW 50090, @msg, 1;
    END CATCH
END
GO
