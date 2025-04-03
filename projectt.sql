-- Task 1: Identifying the Top Branch by Sales Growth Rate (6 Marks)
-- Walmart wants to identify which branch has exhibited the highest sales growth over time. Analyze the total sales
-- for each branch and compare the growth rate across months to find the top performer.

WITH MonthlySales AS (
    SELECT 
        Branch,
        DATE_FORMAT(STR_TO_DATE(Date, '%d-%m-%Y'), '%Y-%m') AS YearMonth,
        SUM(Total) AS TotalSales
    FROM walmartsales
    GROUP BY Branch, YearMonth
),
GrowthRate AS (
    SELECT 
        Branch,
        YearMonth,
        TotalSales,
        LAG(TotalSales) OVER (PARTITION BY Branch ORDER BY YearMonth) AS PrevSales,
      
        CASE 
            WHEN LAG(TotalSales) OVER (PARTITION BY Branch ORDER BY YearMonth) IS NULL THEN 0
            ELSE (TotalSales - LAG(TotalSales) OVER (PARTITION BY Branch ORDER BY YearMonth)) 
                 / LAG(TotalSales) OVER (PARTITION BY Branch ORDER BY YearMonth)
        END AS GrowthRate
    FROM MonthlySales
)
SELECT 
    Branch,
    AVG(GrowthRate) AS AvgGrowthRate
FROM GrowthRate
GROUP BY Branch
ORDER BY AvgGrowthRate DESC
LIMIT 1;

-- Task 2: Finding the Most Profitable Product Line for Each Branch (6 Marks)
-- Walmart needs to determine which product line contributes the highest profit to each branch.The profit margin
-- should be calculated based on the difference between the gross income and cost of goods sold.

WITH Profits AS (
    SELECT 
        Branch,
        ProductLine,
        SUM(grossIncome) AS TotalProfit,
        RANK() OVER (PARTITION BY Branch ORDER BY SUM(grossIncome) DESC) AS Rnk
    FROM walmartsales
    GROUP BY Branch, ProductLine
)
SELECT 
    Branch,
    ProductLine,
    TotalProfit
FROM Profits
WHERE Rnk = 1;

-- Task 3: Analyzing Customer Segmentation Based on Spending (6 Marks)
-- Walmart wants to segment customers based on their average spending behavior. Classify customers into three
-- tiers: High, Medium, and Low spenders based on their total purchase amounts.

WITH TotalSpending AS (
    SELECT 
        CustomerID,
        SUM(Total) AS TotalSpending
    FROM walmartsales
    GROUP BY CustomerID
),
SpendingThresholds AS (
    SELECT 
        MAX(TotalSpending) * 0.67 AS HighThreshold,
        MAX(TotalSpending) * 0.33 AS LowThreshold
    FROM TotalSpending
)

SELECT 
    ts.CustomerID,
    ts.TotalSpending,
    CASE 
        WHEN ts.TotalSpending >= (SELECT HighThreshold FROM SpendingThresholds) THEN 'High'
        WHEN ts.TotalSpending >= (SELECT LowThreshold FROM SpendingThresholds) THEN 'Medium'
        ELSE 'Low'
    END AS SpendingCategory
FROM TotalSpending ts;


-- Task 4: Detecting Anomalies in Sales Transactions (6 Marks)
-- Walmart suspects that some transactions have unusually high or low sales compared to the average for the
-- product line. Identify these anomalies.

WITH ProductLineSeries AS (
    SELECT 
        ProductLine,
        Total AS Sales
    FROM walmartsales
),
ProductLineBounds AS (
    SELECT 
        ProductLine,
        AVG(Sales) - 2*STDDEV(Sales) AS lower_bound,
        AVG(Sales) + 2*STDDEV(Sales) AS upper_bound
    FROM ProductLineSeries
    GROUP BY ProductLine
)
SELECT 
    pls.ProductLine,
    pls.Sales,
    pb.lower_bound,
    pb.upper_bound,
    CASE 
        WHEN pls.Sales NOT BETWEEN pb.lower_bound AND pb.upper_bound THEN 'Anomaly'
        ELSE 'Normal'
    END AS is_anomaly
FROM ProductLineSeries pls
JOIN ProductLineBounds pb
    ON pls.ProductLine = pb.ProductLine;


-- Task 5: Most Popular Payment Method by City (6 Marks)
-- Walmart needs to determine the most popular payment method in each city to tailor marketing strategies.

WITH PaymentCounts AS (
    SELECT 
        City,
        Payment,
        COUNT(*) AS PaymentCount
    FROM walmartsales
    GROUP BY City, Payment
),
MostPopularPayment AS (
    SELECT 
        City,
        Payment,
        PaymentCount,
        RANK() OVER (PARTITION BY City ORDER BY PaymentCount DESC) AS PaymentRank
    FROM PaymentCounts
)
SELECT 
    City,
    Payment AS MostPopularPayment,
    PaymentCount
FROM MostPopularPayment
WHERE PaymentRank = 1;


-- Task 6: Monthly Sales Distribution by Gender (6 Marks)
-- Walmart wants to understand the sales distribution between male and female customers on a monthly basis.

WITH MonthlySales AS (
    SELECT 
        DATE_FORMAT(STR_TO_DATE(Date, '%d-%m-%Y'), '%Y-%m') AS YearMonth,
        Gender,
        SUM(Total) AS TotalSales
    FROM walmartsales
    GROUP BY YearMonth, Gender
)
SELECT 
    YearMonth,
    Gender,
    TotalSales
FROM MonthlySales
ORDER BY YearMonth, Gender;


-- Task 7: Best Product Line by Customer Type (6 Marks)
-- Walmart wants to know which product lines are preferred by different customer types(Member vs. Normal).

WITH SalesByProductLine AS (
    SELECT 
        CustomerType,
        ProductLine,
        SUM(Total) AS TotalSales
    FROM walmartsales
    GROUP BY CustomerType, ProductLine
),
BestProductLine AS (
    SELECT 
        CustomerType,
        ProductLine,
        TotalSales,
        RANK() OVER (PARTITION BY CustomerType ORDER BY TotalSales DESC) AS SalesRank
    FROM SalesByProductLine
)
SELECT 
    CustomerType,
    ProductLine,
    TotalSales
FROM BestProductLine
WHERE SalesRank = 1;

-- Task 8: Identifying Repeat Customers (6 Marks)
-- Walmart needs to identify customers who made repeat purchases within a specific time frame (e.g., within 30
-- days).

WITH CustomerPurchases AS (
    SELECT 
        CustomerID,
        STR_TO_DATE(Dates, '%d-%m-%Y') AS PurchaseDate
    FROM walmartsales
),
RepeatPurchases AS (
    SELECT 
        cp1.CustomerID,
        cp1.PurchaseDate AS FirstPurchaseDate,
        cp2.PurchaseDate AS SecondPurchaseDate,
        DATEDIFF(cp2.PurchaseDate, cp1.PurchaseDate) AS DaysBetween
    FROM CustomerPurchases cp1
    JOIN CustomerPurchases cp2 ON cp1.CustomerID = cp2.CustomerID
    WHERE cp1.PurchaseDate < cp2.PurchaseDate
    AND DATEDIFF(cp2.PurchaseDate, cp1.PurchaseDate) <= 30
)
SELECT DISTINCT CustomerID
FROM RepeatPurchases;

-- Task 9: Finding Top 5 Customers by Sales Volume (6 Marks)
-- Walmart wants to reward its top 5 customers who have generated the most sales Revenue

SELECT 
    CustomerID,
    SUM(Total) AS TotalSales
FROM walmartsales
GROUP BY CustomerID
ORDER BY TotalSales DESC
LIMIT 5;


-- Task 10: Analyzing Sales Trends by Day of the Week (6 Marks)
-- Walmart wants to analyze the sales patterns to determine which day of the week
-- brings the highest sales.

SELECT 
    DAYOFWEEK(STR_TO_DATE(Dates, '%d-%m-%Y')) AS DayOfWeekNumber,  
    SUM(Total) AS TotalSales
FROM walmartsales
GROUP BY DayOfWeekNumber
ORDER BY TotalSales DESC;


-- https://drive.google.com/file/d/164EqAvTQNAdbeY4DmY06q99Y8s8mSu79/view?usp=sharing
-- https://drive.google.com/file/d/164EqAvTQNAdbeY4DmY06q99Y8s8mSu79/view?usp=sharing
-- https://drive.google.com/file/d/164EqAvTQNAdbeY4DmY06q99Y8s8mSu79/view?usp=sharing
