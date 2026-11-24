-- Backfill NULL shipping dates as 7 days after OrderDate
UPDATE [dbo].[FactResellerSales]
SET [ShipDate] = DATEADD(DAY, 7, [OrderDate])
WHERE [ShipDate] IS NULL;
GO

-- Bulk-load incremental June 2020 reseller sales (3,004 rows, UTF-16 encoded)
-- Update the file path below to match your local clone of data/ResellerSales_202006.csv
BULK INSERT [dbo].[FactResellerSales]
FROM 'C:\path\to\repo\data\ResellerSales_202006.csv'
WITH (
    DATAFILETYPE = 'widechar',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO
