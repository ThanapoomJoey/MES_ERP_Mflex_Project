CREATE OR REPLACE VIEW vw_Sales_Customer_Product_Details AS
SELECT
    so.SalesOrderID,
    DATE(so.OrderDate) AS OrderDate,
    DATE(so.RequiredDeliveryDate) AS RequiredDeliveryDate,
    so.OrderStatus,
    so.TotalAmount AS OrderTotalAmount,
    c.CustomerID,
    c.CustomerName,
    sol.SalesOrderLineID,
    sol.ProductID_FK AS ProductID,
    p.ProductName,
    p.ProductType,
    p.TargetYield,
    p.StandardCycleTime_Seconds, 
    sol.QuantityOrdered,
    sol.UnitPrice AS LineUnitPrice,
    sol.LineTotalAmount,
    sol.LineStatus
FROM SalesOrders so
JOIN Customers c ON so.CustomerID_FK = c.CustomerID
JOIN SalesOrderLines sol ON so.SalesOrderID = sol.SalesOrderID_FK
JOIN Products p ON sol.ProductID_FK = p.ProductID;