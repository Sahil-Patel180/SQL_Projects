SELECT d.CalendarYear, d.EnglishMonthName, SUM(SalesAmount) AS MonthlySales
FROM FactResellerSales fr
JOIN DimDate d ON fr.OrderDateKey = d.DateKey
GROUP BY d.CalendarYear, d.MonthNumberOfYear, d.EnglishMonthName
ORDER BY d.CalendarYear, d.MonthNumberOfYear;