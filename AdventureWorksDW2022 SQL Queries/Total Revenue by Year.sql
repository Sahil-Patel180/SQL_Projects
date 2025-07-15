SELECT d.CalendarYear, SUM(fr.SalesAmount) AS TotalSales
FROM FactResellerSales fr
JOIN DimDate d ON fr.OrderDateKey = d.DateKey
GROUP BY d.CalendarYear
ORDER BY d.CalendarYear;