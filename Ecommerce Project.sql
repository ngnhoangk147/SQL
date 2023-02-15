-- Table Schema: https://support.google.com/analytics/answer/3437719?hl=en

-- Query 01: calculate total visit, pageview, transaction and revenue for Jan, Feb and March 2017 order by month
WITH query01 AS
(SELECT totals.visits, 
        totals.pageviews, 
        totals.transactions, 
        totals.totaltransactionRevenue, 
        EXTRACT(MONTH FROM parse_date("%Y%m%d", date)) AS mth
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` 
WHERE  _table_suffix BETWEEN '0101' AND '0331')

SELECT mth, COUNT(visits) as total_visit, 
  SUM(pageviews) AS total_pageviews,
  SUM(transactions) AS total_transactions,
  SUM(totaltransactionRevenue)/1000000 AS totaltransactionRevenue
FROM query01
GROUP BY mth
ORDER BY mth;

-- Query 02: Bounce rate per traffic source in July 2017
SELECT trafficSource.source AS source, 
  COUNT(totals.visits) AS total_visits, 
  COUNT(totals.bounces) AS total_bounces,  
  ROUND(100.0*COUNT(totals.bounces)/COUNT(totals.visits),2) AS bounce_rate
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _table_suffix BETWEEN '0701' AND '0731'
GROUP BY trafficSource.source;

-- Query 3: Revenue by traffic source by week, by month in June 2017
WITH query03 AS
(SELECT totals.totaltransactionRevenue AS revenue,
        trafficSource.source AS source,
        parse_date("%Y%m%d", date) AS date
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`),

june_revenue AS
(SELECT 'MONTH' AS time_type, 
        EXTRACT(MONTH FROM date) AS time, 
        source, 
        SUM(revenue) AS total_revenue
FROM query03
WHERE revenue IS NOT NULL
GROUP BY EXTRACT(MONTH FROM date), source),

june_week_revenue AS
(SELECT 'WEEK' AS time_type, 
        EXTRACT(WEEK FROM date) AS time, 
        source, 
        SUM(revenue) AS total_revenue
FROM query03
WHERE revenue IS NOT NULL
GROUP BY EXTRACT(WEEK FROM date), source)

SELECT * FROM
(SELECT * FROM june_revenue
UNION ALL
SELECT * FROM june_week_revenue)
ORDER BY source, time_type, time

--Query 04: Average number of product pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017. Note: totals.transactions >=1 for purchaser and totals.transactions is null for non-purchaser
#standardSQL

WITH query04 AS
(SELECT totals.pageviews AS pageviews, 
        fullVisitorId, 
        totals.transactions, 
        product.productRevenue,
        hits.transaction.transactionId,
        EXTRACT(MONTH FROM parse_date("%Y%m%d", date)) AS mth,
        (CASE WHEN totals.transactions>=1 THEN 'purchasers'
          WHEN totals.transactions IS NULL THEN 'non-purchasers' END) AS purchasers_type
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
WHERE _table_suffix BETWEEN '0601' AND '0731'),

query04_purchaser AS
(SELECT mth, ROUND(SUM(pageviews)/COUNT(DISTINCT fullVisitorId),2) AS avg_pageviews_per_purchaser
FROM query04
WHERE purchasers_type='purchasers' AND productRevenue IS NOT NULL
GROUP BY mth),

query04_nonpurchaser AS
(SELECT mth, ROUND(SUM(pageviews)/COUNT(DISTINCT fullVisitorId),2) AS avg_pageviews_per_nonpurchaser
FROM query04
WHERE purchasers_type='non-purchasers' AND productRevenue IS NULL
GROUP BY mth)

SELECT q1.mth, avg_pageviews_per_purchaser, avg_pageviews_per_nonpurchaser
FROM query04_purchaser q1
LEFT JOIN query04_nonpurchaser q2
ON q1.mth=q2.mth
ORDER BY q1.mth


SELECT mth, 
      ROUND(SUM(CASE WHEN purchasers_type='purchasers' AND productRevenue IS NOT NULL THEN pageviews END)/
            COUNT(DISTINCT (CASE WHEN purchasers_type='purchasers' AND productRevenue IS NOT NULL THEN fullVisitorId END)),2) AS avg_pageviews_per_purchaser,
      ROUND(SUM(CASE WHEN purchasers_type='non-purchasers' AND productRevenue IS NULL THEN pageviews END)/
            COUNT(DISTINCT (CASE WHEN purchasers_type='non-purchasers' AND productRevenue IS NULL THEN fullVisitorId END)),2) AS avg_pageviews_per_nonpurchaser
FROM query04
GROUP BY mth
ORDER BY mth

-- Query 05: Average number of transactions per user that made a purchase in July 2017
#standardSQL

WITH query05 AS
(SELECT totals.pageviews AS pageviews, 
        fullVisitorId, product.productRevenue AS revenue, 
        totals.transactions AS transaction,
        EXTRACT(MONTH FROM parse_date("%Y%m%d", date)) AS mth,
        (CASE WHEN totals.transactions>=1 THEN 'purchasers'
          WHEN totals.transactions IS NULL THEN 'non-purchasers' END) AS purchasers_type
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product)

SELECT '201707' AS month, 
      ROUND(SUM(transaction)/COUNT(DISTINCT fullVisitorId),2) AS avg_transaction_per_user
FROM query05
WHERE revenue IS NOT NULL and purchasers_type='purchasers';

-- Query 06: Average amount of money spent per session

SELECT
    FORMAT_DATE("%Y%m",PARSE_DATE("%Y%m%d",date)) as month,
    ((SUM(totals.totalTransactionRevenue)/SUM(totals.visits))/POWER(10,6)) as avg_revenue_by_user_per_visit
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
WHERE product.productRevenue is not null
GROUP BY month;

-- Query 07: Other products purchased by customers who purchased product "YouTube Men's Vintage Henley" in July 2017. Output should show product name and the quantity was ordered.
#standardSQL
WITH query07 AS
(SELECT DISTINCT fullVisitorId
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
WHERE product.v2ProductName="YouTube Men's Vintage Henley" 
  AND product.productQuantity>=1
  AND product.productRevenue IS NOT NULL),

query07_2 AS
(SELECT product.v2ProductName, product.productQuantity
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` t1,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
INNER JOIN query07 t2
ON t1.fullVisitorId=t2.fullVisitorId
WHERE product.v2ProductName!="YouTube Men's Vintage Henley"
  AND product.productQuantity>=1
  AND product.productRevenue IS NOT NULL)

SELECT v2ProductName, 
      SUM(productQuantity) AS count
FROM query07_2
GROUP BY v2ProductName
ORDER BY count DESC


--Query 08: Calculate cohort map from pageview to addtocart to purchase in last 3 month. For example, 100% pageview then 40% add_to_cart and 10% purchase.
#standardSQL
WITH query08 AS
(SELECT hits.eCommerceAction.action_type, 
        visitId, 
        product.productRevenue,
  EXTRACT(MONTH FROM PARSE_DATE('%Y%m%d', date)) AS mth
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
  -- UNNEST(eCommerceAction) AS eCommerceAction
WHERE _table_suffix BETWEEN '0101' AND '0331'
  AND (hits.eCommerceAction.action_type='2'
  OR hits.eCommerceAction.action_type='3'
  OR hits.eCommerceAction.action_type='6')),

query08_2 AS
(SELECT mth,
  SUM(CASE WHEN action_type='2' THEN 1 ELSE 0 END) AS number_product_view,
  SUM(CASE WHEN action_type='3' THEN 1 ELSE 0 END) AS number_addtocart,
  SUM(CASE WHEN action_type='6' AND productRevenue IS NOT NULL THEN 1 ELSE 0 END) AS number_purchase
FROM query08
GROUP BY mth
ORDER BY mth)

SELECT *, ROUND(100.0*number_addtocart/number_product_view,2) AS addtocart_rate,
  ROUND(100.0*number_purchase/number_product_view,2) AS purchase_rate
FROM query08_2;
