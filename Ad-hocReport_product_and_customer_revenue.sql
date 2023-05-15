-- Question 1
-- Gather customer information
WITH cust_info AS (
SELECT CONCAT(CONCAT(first_name,' '),last_name) AS name, cu.CUSTOMER_ID, PHONE
FROM customers cu
LEFT JOIN contacts co
ON cu.customer_id = co.customer_id
),
-- Gather revenue information
orders_info AS (
SELECT o.order_id, customer_id, product_id,
    (quantity*unit_price) AS sales
FROM orders o
INNER JOIN order_items oi
ON o.order_id = oi.order_id
WHERE status = 'Shipped'
),
-- Gather product id, category name
product_info AS (
SELECT product_id, category_name
FROM products p
INNER JOIN product_categories pc
ON p.category_id = pc.category_id
),

-- Collect customer name, sales, rank sales by category
product_sales AS (
SELECT name, order_id, sales, category_name, phone
FROM cust_info c
INNER JOIN orders_info o
ON c.customer_id = o.customer_id
INNER JOIN product_info p
ON o.product_id = p.product_id
),
summary AS (
SELECT category_name, name, SUM(sales) AS total_sales, phone,
RANK() OVER(PARTITION BY category_name ORDER BY SUM(sales) DESC) as rank
FROM product_sales
GROUP BY category_name, name, phone
)

SELECT category_name, name, total_sales, phone
FROM summary
WHERE rank=1;

-- Question 2
-- Gather customer information
WITH cust_info AS (
SELECT CONCAT(CONCAT(first_name,' '),last_name) AS customer_name, 
    cu.CUSTOMER_ID, website
FROM customers cu
LEFT JOIN contacts co
ON cu.customer_id = co.customer_id
),
-- Gather revenue information
order_product AS (
SELECT order_id, product_name, (quantity*unit_price) AS sales
FROM order_items oi
INNER JOIN products p
ON oi.product_id = p.product_id
),
-- Gather customer's order information
customer_order AS (
SELECT customer_name, website, product_name, sales
FROM cust_info c
INNER JOIN orders o
ON c.customer_id = o.customer_id
INNER JOIN order_product op
ON o.order_id = op.order_id
WHERE status = 'Shipped'
),
-- Summary information and identify 3 products with the highest sales
summary AS (
SELECT customer_name, website, product_name, SUM(sales) AS total_sales
FROM customer_order
GROUP BY customer_name, website, product_name
ORDER BY customer_name
),
rank_summary AS (
SELECT customer_name, website, product_name, total_sales,
    DENSE_RANK() OVER(PARTITION BY customer_name ORDER BY total_sales DESC) AS rank
FROM summary
)
SELECT customer_name, website, product_name, total_sales
FROM rank_summary
WHERE rank<=3;

-- Question 3
-- Gather revenue information with product and category
WITH product_order AS (
SELECT category_name, product_name, (quantity*unit_price) AS sales
FROM order_items oi
INNER JOIN products p
ON oi.product_id = p.product_id
INNER JOIN product_categories pc
ON p.category_id = pc.category_id
INNER JOIN orders o
ON oi.order_id = o.order_id
WHERE status = 'Shipped'
),
-- Calculate product sales by category
product_sales AS (
SELECT category_name, product_name, SUM(sales) AS total_product_sales
FROM product_order
GROUP BY category_name, product_name
ORDER BY category_name, product_name
),
category_product_sale AS (
SELECT category_name, product_name, total_product_sales,
    SUM(total_product_sales) OVER(PARTITION BY category_name) AS total_category_sales
FROM product_sales
)

SELECT category_name, product_name, CAST(total_product_sales AS char(20)) AS total_product_sales, total_category_sales,
    CONCAT(ROUND((total_product_sales/total_category_sales)*100, 2),'%') AS percentage
FROM category_product_sale
UNION 
SELECT 'total_sale' ,'','', SUM(total_product_sales), ''
FROM category_product_sale;

-- Question 4
-- Gather customer information
WITH cust_info AS (
SELECT CONCAT(CONCAT(first_name,' '),last_name) AS name, cu.CUSTOMER_ID, PHONE
FROM customers cu
LEFT JOIN contacts co
ON cu.customer_id = co.customer_id
),
-- Calculate sales from new customer by month
customer_sale_month AS (
SELECT customer_id, (quantity*unit_price) AS sales,
    TO_CHAR(order_date, 'YYYY-MM') AS year_month
FROM orders o
INNER JOIN order_items oi
ON o.order_id = oi.order_id
WHERE status='Shipped'
),
month_rank AS (
SELECT customer_id, year_month, SUM(sales) AS total_sales,
    RANK() OVER(PARTITION BY customer_id ORDER BY year_month) AS rank
FROM customer_sale_month
GROUP BY customer_id, year_month
)
-- Calculate total sales from new customer by month
SELECT year_month, name, phone, total_sales
FROM month_rank mr
INNER JOIN cust_info c
ON mr.customer_id = c.customer_id
WHERE rank=1
UNION
SELECT CONCAT(year_month, '_total_new_sales'), '', '', SUM(total_sales)
FROM month_rank
WHERE rank=1
GROUP BY year_month;

-- Question 5
-- Gather order time of customer and entered time
WITH customer_time AS (
SELECT customer_id,
    TRUNC(order_date, 'MM') AS first_day_of_month,
    to_date('&p_month','YYYY-MM') AS p_month
from orders
WHERE status='Shipped'
),
-- Calculate interval
month_interval AS (
SELECT customer_id, p_month, first_day_of_month, 
    MONTHS_BETWEEN(p_month, first_day_of_month) as month_interval
FROM customer_time
where p_month > first_day_of_month
),
pmonth_minus3 AS (
SELECT customer_id, month_interval
FROM month_interval
WHERE month_interval>=3
),
pmonth_minus12 AS (
SELECT customer_id, month_interval
FROM month_interval
WHERE month_interval=2 OR month_interval=1
),
-- Gather customer id that haven't purchased for 2 last month
cust AS (
SELECT customer_id
FROM pmonth_minus3
MINUS
SELECT customer_id
FROM pmonth_minus12
)
SELECT CONCAT(CONCAT(first_name,' '),last_name) AS customer_name,
    phone
FROM contacts ct
INNER JOIN cust c
ON ct.customer_id = c.customer_id;

-- Quesion 6:
-- Gather information about product name and product quantity in the warehouse
WITH product_quantity AS (
SELECT i.product_id, quantity, product_name, warehouse_id
FROM inventories i
INNER JOIN products p
ON i.product_id = p.product_id
),
-- Gather country name and warehouse name
warehouse_country AS (
SELECT warehouse_name, country_name, warehouse_id
FROM warehouses w
INNER JOIN locations l
ON w.location_id = l.location_id
INNER JOIN countries c
ON l.country_id = c.country_id
),
-- Rank product quantity by country in ascending order
summary AS (
SELECT product_id, product_name, warehouse_name, country_name, quantity,
   RANK() OVER(PARTITION BY country_name ORDER BY quantity) AS ranking
FROM product_quantity p
INNER JOIN warehouse_country w
ON p.warehouse_id = w.warehouse_id
)
-- Extract the list with rank <=100
SELECT product_id, product_name, warehouse_name, country_name, quantity
FROM summary
WHERE ranking <=100;


--Question 7:
-- Gather product id, sold quantity, order date and the last order date
WITH product_quantity AS (
SELECT product_id, quantity, order_date, 
    MAX(order_date) OVER() AS max_date
FROM order_items oi
INNER JOIN orders o
ON oi.order_id = o.order_id
WHERE status='Shipped'
),
-- Calculate sold rate per day in last 30 days 
product_quantity_last30 AS (
SELECT product_id, SUM(quantity)/30 AS sold_quantity_rate
FROM product_quantity
WHERE order_date >= max_date - 30
GROUP BY product_id
),
-- Calculate the number of days that will sell out
summary AS (
SELECT p.product_id, product_name, ROUND((quantity/sold_quantity_rate),0) AS nb_days, warehouse_id
FROM product_quantity_last30 p30
INNER JOIN products p
ON p30.product_id = p.product_id
INNER JOIN inventories i
ON p.product_id = i.product_id
)
-- Gather warehouse name
SELECT warehouse_name, product_name, nb_days
FROM summary s
INNER JOIN warehouses w
ON s.warehouse_id = w.warehouse_id
ORDER BY warehouse_name, product_name


--Question 8:
-- Gather customer information
WITH cust_info AS (
SELECT CONCAT(CONCAT(first_name,' '),last_name) AS name, cu.customer_id, phone
FROM customers cu
LEFT JOIN contacts co
ON cu.customer_id = co.customer_id
),
-- Gather revenue information
orders_info AS (
SELECT o.order_id, customer_id, product_id,
    (quantity*unit_price) AS sales
FROM orders o
INNER JOIN order_items oi
ON o.order_id = oi.order_id
WHERE status = 'Shipped'
),
-- Calculate revenue from each customer
customer_sales AS (
SELECT c.customer_id, name, SUM(sales) AS total_sales
FROM cust_info c
INNER JOIN orders_info o
ON c.customer_id = o.customer_id
GROUP BY c.customer_id, name
ORDER BY total_sales DESC
),
-- Calculate total sale and cumulative total sale, sorted in descending order by sales of each customer
summary AS (
SELECT customer_id, name, total_sales,
    SUM(total_sales) OVER() AS total_revenue,
    SUM(total_sales) OVER(ORDER BY total_sales DESC ROWS BETWEEN 
        UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM customer_sales
)
-- Get the list of customers contributing 80% of sales
SELECT customer_id, name, total_sales
FROM summary
WHERE running_total/total_revenue<=0.8


-- Question 9: 
-- Gather orders information with order year and current year
WITH orders_info AS (
SELECT product_id, SUM(quantity*unit_price) AS sales,
    EXTRACT(YEAR FROM order_date) AS yr,
    MAX(EXTRACT(YEAR FROM order_date)) OVER() AS current_yr
FROM orders o
INNER JOIN order_items oi
ON o.order_id = oi.order_id
WHERE status = 'Shipped'
GROUP BY product_id, EXTRACT(YEAR FROM order_date)
),
-- Calculate the last and current year total sales by product
cur_last_year_sales AS (
SELECT product_id, 
    SUM(CASE WHEN yr=current_yr THEN sales END) AS current_sales,
    SUM(CASE WHEN yr=current_yr-1 THEN sales END) AS last_sales
FROM orders_info
GROUP BY product_id
),
-- Gather category name, product name and calculate growth rate  by product
summary AS (
SELECT category_name, product_name, current_sales, last_sales,
    ROUND((current_sales-last_sales)*100/last_sales,2) AS growth_rate
FROM cur_last_year_sales c
INNER JOIN products p
ON c.product_id = p.product_id
INNER JOIN product_categories pc
ON p.category_id = pc.category_id
)
-- Calculate total sales by category, total full-year sales and growth rate
SELECT category_name, product_name, current_sales, last_sales, growth_rate
FROM summary
UNION
SELECT CONCAT(category_name,'_total'), '',
    SUM(current_sales), SUM(last_sales),
    ROUND((SUM(current_sales)-SUM(last_sales))*100/SUM(last_sales),2)
FROM summary
GROUP BY category_name
UNION
SELECT '_total_sales', '',
    SUM(current_sales), SUM(last_sales),
    ROUND((SUM(current_sales)-SUM(last_sales))*100/SUM(last_sales),2)
FROM summary
