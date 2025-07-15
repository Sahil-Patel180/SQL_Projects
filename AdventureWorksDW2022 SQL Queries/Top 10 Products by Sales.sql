SELECT p.EnglishProductName, SUM(fr.SalesAmount) AS Revenue
FROM FactResellerSales fr
JOIN DimProduct p ON fr.ProductKey = p.ProductKey
GROUP BY p.EnglishProductName
ORDER BY Revenue DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;