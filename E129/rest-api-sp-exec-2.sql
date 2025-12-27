DECLARE @Q1 nvarchar(max) = N'EVALUATE ''Product''';
DECLARE @Q2 nvarchar(max) = N'EVALUATE VALUES(''Product''[Category]) ORDER BY ''Product''[Category]';
DECLARE @Q3 nvarchar(max) =
N'DEFINE VAR __Base = SUMMARIZECOLUMNS(''Product''[Product], "Profit", [Profit], "Orders", [Orders])
VAR __Top = TOPN(20, __Base, [Profit], DESC, ''Product''[Product], ASC)
EVALUATE __Top
ORDER BY [Profit] DESC, ''Product''[Product]';


EXEC dbo.ConnectPowerBIExecuteDaxQuery
    @TenantId          = N'...',
    @ClientId          = N'...',
    @ClientSecret      = N'...',
    @WorkspaceId       = N'...',  
    @DatasetId         = N'...',
    @Dax               = @Q3,              
    @IncludeNulls      = 1,
    @ReturnRawResponse = 0;



