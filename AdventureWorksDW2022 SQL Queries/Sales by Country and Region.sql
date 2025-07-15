SELECT g.CountryRegionCode, g.StateProvinceName, SUM(fr.SalesAmount) AS TotalSales
FROM FactResellerSales fr
JOIN DimGeography g ON fr.SalesTerritoryKey = g.SalesTerritoryKey
GROUP BY g.CountryRegionCode, g.StateProvinceName
ORDER BY TotalSales DESC;