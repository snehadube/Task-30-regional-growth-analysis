-- ============================================================
-- Regional Growth Analysis  |  Veda Technology - Data Analytics Track
-- Dataset : Superstore (superstore.csv, 9,994 rows, orders 2014-2017)
-- Engine  : SQLite (tested). Window functions need SQLite 3.25+ ;
--           MySQL 8 / PostgreSQL / SQL Server also support LAG().
--           Only the date functions (strftime / POWER) differ slightly.
-- ============================================================

-- STEP 0: load superstore.csv into a table called `superstore`
-- (DB Browser for SQLite: File > Import > Table from CSV file...)
-- Column names are lower_case_with_underscores, order_date as YYYY-MM-DD.

-- STEP 1: one clean view with year and quarter so every query uses
-- the SAME period definition (calendar year / calendar quarter).
DROP VIEW IF EXISTS orders_clean;
CREATE VIEW orders_clean AS
SELECT order_id,
       region,
       sales,
       profit,
       CAST(strftime('%Y', order_date) AS INTEGER) AS order_year,
       CAST(strftime('%Y', order_date) AS INTEGER) * 10
         + ((CAST(strftime('%m', order_date) AS INTEGER) + 2) / 3) AS yq,
       strftime('%Y', order_date) || '-Q'
         || ((CAST(strftime('%m', order_date) AS INTEGER) + 2) / 3) AS order_quarter
FROM superstore;

-- quick sanity checks before analysis
SELECT COUNT(*) AS total_rows, MIN(order_date) AS first_order, MAX(order_date) AS last_order FROM superstore;
SELECT region, COUNT(*) AS rows_per_region FROM superstore GROUP BY region;

-- Q1. Yearly sales, profit, orders and YoY growth by region
WITH yearly AS (
    SELECT region,
           order_year,
           ROUND(SUM(sales), 2)  AS sales,
           ROUND(SUM(profit), 2) AS profit,
           COUNT(DISTINCT order_id) AS orders
    FROM orders_clean
    GROUP BY region, order_year
)
SELECT region,
       order_year,
       sales,
       ROUND(sales - LAG(sales) OVER (PARTITION BY region ORDER BY order_year), 2) AS sales_change,
       ROUND(100.0 * (sales - LAG(sales) OVER (PARTITION BY region ORDER BY order_year))
             / LAG(sales) OVER (PARTITION BY region ORDER BY order_year), 2)       AS sales_yoy_pct,
       profit,
       ROUND(100.0 * (profit - LAG(profit) OVER (PARTITION BY region ORDER BY order_year))
             / LAG(profit) OVER (PARTITION BY region ORDER BY order_year), 2)      AS profit_yoy_pct,
       orders,
       ROUND(100.0 * profit / sales, 2) AS margin_pct
FROM yearly
ORDER BY region, order_year;

-- Q2. Compound annual growth (CAGR) 2014 to 2017 - smooths out the year-to-year noise
WITH yearly AS (
    SELECT region, order_year, SUM(sales) AS sales
    FROM orders_clean
    GROUP BY region, order_year
)
SELECT a.region,
       ROUND(a.sales, 0) AS sales_2014,
       ROUND(b.sales, 0) AS sales_2017,
       ROUND(b.sales - a.sales, 0) AS absolute_gain,
       ROUND(100 * (POWER(b.sales / a.sales, 1.0 / 3) - 1), 2) AS sales_cagr_pct
FROM yearly a
JOIN yearly b ON a.region = b.region AND a.order_year = 2014 AND b.order_year = 2017
ORDER BY sales_cagr_pct DESC;

-- Q3. Quarterly sales vs the SAME quarter last year (removes Q4 seasonality)
WITH q AS (
    SELECT region, order_quarter, yq, ROUND(SUM(sales), 2) AS sales
    FROM orders_clean
    GROUP BY region, order_quarter, yq
)
SELECT region,
       order_quarter,
       sales,
       LAG(sales, 4) OVER (PARTITION BY region ORDER BY yq) AS same_qtr_last_year,
       ROUND(100.0 * (sales - LAG(sales, 4) OVER (PARTITION BY region ORDER BY yq))
             / LAG(sales, 4) OVER (PARTITION BY region ORDER BY yq), 2) AS qtr_yoy_pct
FROM q
ORDER BY region, yq;

-- Q4. Small-base check - flag growth where last year's base was under 50% of the region's own 4-year average
WITH yearly AS (
    SELECT region, order_year, SUM(profit) AS profit
    FROM orders_clean
    GROUP BY region, order_year
),
with_prev AS (
    SELECT region, order_year, profit,
           LAG(profit) OVER (PARTITION BY region ORDER BY order_year) AS prev_profit,
           AVG(profit) OVER (PARTITION BY region)                      AS avg_profit
    FROM yearly
)
SELECT region,
       order_year,
       ROUND(prev_profit, 0) AS base_profit,
       ROUND(profit, 0)      AS profit,
       ROUND(profit - prev_profit, 0) AS absolute_change,
       ROUND(100.0 * (profit - prev_profit) / prev_profit, 1) AS growth_pct,
       CASE WHEN prev_profit < 0.5 * avg_profit THEN 'SMALL BASE' ELSE 'ok' END AS base_flag
FROM with_prev
WHERE prev_profit IS NOT NULL
ORDER BY ABS(100.0 * (profit - prev_profit) / prev_profit) DESC;

-- Q5. Who actually added the most dollars between 2014 and 2017?
WITH yearly AS (
    SELECT region, order_year, SUM(sales) AS sales
    FROM orders_clean
    GROUP BY region, order_year
),
gain AS (
    SELECT a.region, b.sales - a.sales AS gain
    FROM yearly a
    JOIN yearly b ON a.region = b.region AND a.order_year = 2014 AND b.order_year = 2017
)
SELECT region,
       ROUND(gain, 0) AS sales_gain,
       ROUND(100.0 * gain / (SELECT SUM(gain) FROM gain), 1) AS pct_of_company_gain
FROM gain
ORDER BY gain DESC;

-- Q6. South 2014 base - how much of it is a single order?
SELECT order_id, order_date, state, product_name,
       ROUND(sales, 2) AS sales,
       ROUND(100.0 * sales / (SELECT SUM(sales) FROM orders_clean
                              WHERE region = 'South' AND order_year = 2014), 1) AS pct_of_south_2014
FROM superstore
WHERE region = 'South' AND substr(order_date, 1, 4) = '2014'
ORDER BY sales DESC
LIMIT 3;

-- Q7. Average discount and margin by region and year (why did Central profit fall?)
SELECT region,
       substr(order_date, 1, 4) AS order_year,
       ROUND(AVG(discount), 3)  AS avg_discount,
       ROUND(100.0 * SUM(profit) / SUM(sales), 2) AS margin_pct
FROM superstore
GROUP BY region, substr(order_date, 1, 4)
ORDER BY region, order_year;

-- Q8. Loss-making states inside Central (2016-2017)
SELECT state,
       substr(order_date, 1, 4) AS order_year,
       ROUND(SUM(sales), 0)  AS sales,
       ROUND(SUM(profit), 0) AS profit
FROM superstore
WHERE region = 'Central' AND substr(order_date, 1, 4) IN ('2016', '2017')
GROUP BY state, substr(order_date, 1, 4)
HAVING SUM(profit) < 0
ORDER BY profit;
