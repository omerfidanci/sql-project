-----------------------------------------------
/*
E-Commerce Data and Customer Retention Analysis with SQL
_________________________________________________________
An e-commerce organization demands some analysis of sales and shipping processes. Thus, the organization hopes to be able to predict more easily the opportunities and threats for the future.
Acording to this scenario, You are asked to make the following analyzes consistant with following the instructions given.

Introduction
- You have to create a database and import into the given csv file. (You should research how to import a .csv file)
- During the import process, you will need to adjust the date columns. You need to carefully observe the data types and how they should be.
- The data are not very clean and fully normalized. However, they don't prevent you from performing the given tasks.
- Manually verify the accuracy of your analysis.
*/

-- -------------------------------------------------------
-- Analyze the data by finding the answers to the questions below:

use ProjectECommerce;

-- 1. Find the top 3 customers who have the maximum count of orders.

SELECT TOP(3)
	Cust_ID,
	COUNT(DISTINCT Ord_ID) order_count
FROM dbo.comm
GROUP BY Cust_ID
ORDER BY order_count DESC

-- 2. Find the customer whose order took the maximum time to get shipping.

SELECT Cust_ID, Customer_Name, DaysTakenForShipping
FROM dbo.comm
WHERE DaysTakenForShipping = (
	SELECT MAX(DaysTakenForShipping)
	FROM dbo.comm)

-- 3. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

WITH cte AS
	(SELECT DISTINCT Cust_ID
			FROM dbo.e_commerce_data
			WHERE	MONTH(Order_Date) = 1 AND 
					YEAR(Order_Date) = 2011)
SELECT	MONTH(e.Order_Date) AS months_2011, 
		COUNT(DISTINCT cte.Cust_ID) as monthly_total_customers
FROM	cte, 
		e_commerce_data e 
WHERE	cte.Cust_ID = e.Cust_ID AND 
		YEAR(e.Order_Date) = 2011
GROUP BY MONTH(e.Order_Date)
ORDER BY MONTH(e.Order_Date);



--4. Write a query to return for each user the time elapsed between the first purchasing and the third purchasing, in ascending order by Customer ID.

WITH a AS(
    SELECT 
    	Cust_ID, 
    	Customer_Name, 
        COUNT(Ord_ID) as total_orders 
    FROM dbo.e_commerce_data
    GROUP BY Cust_ID, Customer_Name
    HAVING COUNT(Ord_ID) > 2), 

	b AS (
	SELECT 
		a.Cust_ID, 
		a.Customer_Name, 
		d.Order_Date,
        LEAD(d.Order_Date, 2) OVER (PARTITION BY a.Cust_ID, a.Customer_Name ORDER BY a.Cust_ID, d.Order_Date) as third_order,
        ROW_NUMBER() OVER(PARTITION BY a.Cust_ID, a.Customer_Name ORDER BY a.Cust_ID, d.Order_Date) AS order_number
    FROM a, dbo.e_commerce_data d
    WHERE a.Cust_ID = d.Cust_ID) 

SELECT 
	b.Cust_ID, 
	b.Customer_Name, 
	b.Order_Date, 
	b.third_order, 
    DATEDIFF(DAY, Order_Date, third_order) as time_elapse
FROM b 
WHERE b.order_number = 1;


--5. Write a query that returns customers who purchased both product 11 and product 14, as well as the ratio of these products to the total number of products purchased by the customer.

-- first part

WITH p11_14 as (
    SELECT 
    	Cust_ID, 
    	Customer_Name
    FROM e_commerce_data
    WHERE Prod_ID = 'Prod_11'

    INTERSECT 

    SELECT 
    	Cust_ID, 
    	Customer_Name
    FROM e_commerce_data
    WHERE Prod_ID = 'Prod_14'
    )

SELECT 
	p11_14.Cust_ID, 
	p11_14.Customer_Name, 
	d.Prod_ID,
    CASE WHEN d.prod_ID IN ('Prod_11', 'Prod_14') THEN 1 ELSE 0 END as prod_11_14,
    COUNT(d.prod_ID) OVER(PARTITION BY p11_14.Cust_ID, p11_14.Customer_Name) as total_products
FROM 
	p11_14, 
	e_commerce_data d 
WHERE 
	p11_14.Cust_ID = d.Cust_ID AND 
	p11_14.Customer_Name = d.Customer_Name
ORDER BY p11_14.Cust_ID;

-- second part

WITH p11_14 as (
    SELECT 
    	Cust_ID, 
    	Customer_Name
    FROM e_commerce_data
    WHERE Prod_ID = 'Prod_11'
    
    INTERSECT 
    
    SELECT 
    	Cust_ID, 
    	Customer_Name
    FROM e_commerce_data
    WHERE Prod_ID = 'Prod_14'
    ),

s as (
    SELECT 
    	DISTINCT p11_14.Cust_ID, 
    	p11_14.Customer_Name,
        SUM(CASE WHEN d.prod_ID IN ('Prod_11', 'Prod_14') THEN 1 ELSE 0 END) OVER (PARTITION BY p11_14.Cust_ID, p11_14.Customer_Name) as prod_11_14,
        COUNT(d.prod_ID) OVER(PARTITION BY p11_14.Cust_ID, p11_14.Customer_Name) as total_products
    FROM 
    	p11_14, 
    	e_commerce_data d 
    WHERE 
    	p11_14.Cust_ID = d.Cust_ID AND 
    	p11_14.Customer_Name = d.Customer_Name
    )

SELECT 
	s.Cust_ID, 
    s.Customer_Name, 
    s.prod_11_14, s.total_products,
    100 *s.prod_11_14/s.total_products as Percentage_11_14
FROM s
ORDER BY s.Cust_ID;

/*
Customer Segmentation
Categorize customers based on their frequency of visits. The following steps will guide you. If you want, you can track your own way.
*/
--1. Create a “view” that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)

CREATE or ALTER VIEW customer_log AS 
SELECT Cust_ID,
    YEAR(Order_Date) AS o_year,
    MONTH(Order_Date) AS o_month
FROM e_commerce_data

SELECT * 
FROM customer_log
ORDER BY o_year, o_month


--2. Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning business)
CREATE or ALTER VIEW monthly_visits AS
SELECT
    YEAR(order_date) as o_year, 
    MONTH(order_date) as o_month, 
    COUNT(*) as monthly_visits
FROM e_commerce_data
GROUP BY YEAR(order_date), MONTH(order_date);


SELECT * 
FROM monthly_visits
ORDER BY o_year, o_month;

--3. For each visit of customers, create the next month of the visit as a separate column.

SELECT 
	Cust_ID, 
    Customer_Name,
	Ord_ID,
    Order_Date,
	MONTH(LEAD(Order_Date) OVER (PARTITION BY Cust_ID, Customer_Name ORDER BY Cust_ID, Order_Date)) as next_order_month
FROM e_commerce_data


-- 4. Calculate the monthly time gap between two consecutive visits by each customer.

CREATE VIEW order_time_gap AS 
SELECT 
	Cust_ID, 
    Customer_Name,
	Ord_ID,
    Order_Date,
	LEAD(Order_Date) OVER (PARTITION BY Cust_ID, Customer_Name ORDER BY Cust_ID, Order_Date) as next_order,
    DATEDIFF(MONTH, Order_Date, LEAD(Order_Date) OVER (PARTITION BY Cust_ID, Customer_Name ORDER BY Cust_ID, Order_Date)) as time_gap_between_orders
FROM e_commerce_data;


--5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.
--For example:
--o Labeled as churn if the customer hasn't made another purchase in the months since they made their first purchase.
--o Labeled as regular if the customer has made a purchase every month.
--Etc.

WITH nord AS(
    SELECT 
    	Cust_ID, 
        Customer_Name,
	    Ord_ID,
        Order_Date,
		LEAD(Order_Date) OVER (PARTITION BY Cust_ID, Customer_Name ORDER BY Cust_ID, Order_Date) as next_order, 
		DATEDIFF(MONTH,Order_Date, LEAD(Order_Date) OVER (PARTITION BY Cust_ID, Customer_Name ORDER BY Cust_ID, Order_Date)) as time_gap_between_orders
	FROM e_commerce_data
    )

SELECT Cust_ID, 
    Customer_Name, 
    AVG(time_gap_between_orders) as avg_time_gap,
    CASE
    	WHEN AVG(time_gap_between_orders) IS NULL THEN 'Churn'
    	WHEN AVG(time_gap_between_orders) <= 24 THEN 'Regular'
        WHEN AVG(time_gap_between_orders) > 24 THEN 'Potential Churn'
    END AS churn_status
FROM nord 
GROUP BY 
	Cust_ID, 
	Customer_Name
ORDER BY AVG(time_gap_between_orders);

/*
Month-Wise Retention Rate
Find month-by-month customer retention ratei since the start of the business.
There are many different variations in the calculation of Retention Rate. But we will try to calculate the month-wise retention rate in this project.
So, we will be interested in how many of the customers in the previous month could be retained in the next month.
Proceed step by step by creating “views”. You can use the view you got at the end of the Customer Segmentation section as a source.
*/

--1. Find the number of customers retained month-wise. (You can use time gaps)

SELECT * 
FROM order_time_gap
WHERE time_gap_between_orders is not null
ORDER BY time_gap_between_orders

WITH ret AS (
	SELECT  
		Cust_ID, YEAR(Order_Date) as years, 
		MONTH(Order_Date) as months,
        COUNT(Cust_ID) OVER(PARTITION BY YEAR(Order_Date), MONTH(Order_Date) ORDER BY YEAR(Order_Date), MONTH(Order_Date)) as monthly_retained
    FROM order_time_gap
	WHERE time_gap_between_orders = 1
	)

SELECT 
	years, 
	months, 
	COUNT(monthly_retained) as monthly_retained_customers
FROM ret
GROUP BY years, months
ORDER BY years, months;


--2. Calculate the month-wise retention rate.
CREATE VIEW Month_Wise_Retention_Rate AS

SELECT DISTINCT YEAR(order_date) [year],
                MONTH(order_date) [month],
                DATENAME(MONTH,order_date) [month_name],
                COUNT(cust_id) OVER (PARTITION BY YEAR(order_date), 
                MONTH(order_date) ORDER BY YEAR(order_date), 
                MONTH(order_date)) num_cust
FROM dbo.e_commerce_data

SELECT YEAR, MONTH, num_cust, LEAD(num_cust,1) OVER (ORDER BY YEAR, MONTH) rate_,
        FORMAT(num_cust*1.0/(LEAD(num_cust,1) OVER (ORDER BY YEAR, MONTH, num_cust)),'N2')
FROM Month_Wise_Retention_Rate
