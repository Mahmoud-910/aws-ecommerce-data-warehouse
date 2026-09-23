-- ============================================================
-- AWS Athena Analytics Queries
-- Source schema: default/current Athena database
-- Grain assumptions:
--   fact_order_detail   = one product line per order
--   fact_order         = one row per order
--   fact_customer_sales = one customer per day
--   fact_product_sales  = one product per day
-- ============================================================

-- Task 29: Overall KPIs
-- Use fact_order_detail for line-level sales and quantity.
-- Use fact_order for order count to avoid line-item duplication.
WITH kpis AS (
    SELECT
        SUM(net_sales) AS total_sales,
        SUM(quantity) AS total_quantity_sold,
        SUM(profit) AS total_profit
    FROM fact_order_detail
), order_kpis AS (
    SELECT COUNT(DISTINCT order_id) AS total_orders
    FROM fact_order
), customer_kpis AS (
    SELECT COUNT(DISTINCT customer_key) AS total_customers
    FROM dim_customer
), product_kpis AS (
    SELECT COUNT(DISTINCT product_key) AS total_products
    FROM dim_product
)
SELECT
    k.total_sales,
    o.total_orders,
    c.total_customers,
    p.total_products,
    k.total_quantity_sold,
    k.total_profit
FROM kpis k
CROSS JOIN order_kpis o
CROSS JOIN customer_kpis c
CROSS JOIN product_kpis p;


-- Task 30: Monthly sales, orders, quantity, and profit
SELECT
    d.year,
    d.month,
    d.month_name,
    SUM(f.net_sales) AS sales,
    COUNT(DISTINCT f.order_id) AS orders,
    SUM(f.quantity) AS quantity,
    SUM(f.profit) AS profit
FROM fact_order_detail f
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;


-- Task 31A: Sales by category
SELECT
    c.category_id,
    c.category_name,
    SUM(f.net_sales) AS total_sales,
    SUM(f.quantity) AS quantity_sold,
    COUNT(DISTINCT f.order_id) AS order_count,
    SUM(f.profit) AS total_profit
FROM fact_order_detail f
JOIN dim_product p
    ON f.product_key = p.product_key
JOIN dim_category c
    ON p.category_key = c.category_key
GROUP BY c.category_id, c.category_name
ORDER BY total_sales DESC;


-- Task 31B: Sales by department
-- This requires dim_product.department_key to be populated.
SELECT
    d.department_id,
    d.department_name,
    SUM(f.net_sales) AS total_sales,
    SUM(f.quantity) AS quantity_sold,
    COUNT(DISTINCT f.order_id) AS order_count,
    SUM(f.profit) AS total_profit
FROM fact_order_detail f
JOIN dim_product p
    ON f.product_key = p.product_key
JOIN dim_department d
    ON p.department_key = d.department_key
GROUP BY d.department_id, d.department_name
ORDER BY total_sales DESC;


-- Task 31C: Sales by product
SELECT
    p.product_id,
    p.product_name,
    p.brand,
    SUM(f.net_sales) AS total_sales,
    SUM(f.quantity) AS quantity_sold,
    COUNT(DISTINCT f.order_id) AS order_count,
    SUM(f.profit) AS total_profit
FROM fact_order_detail f
JOIN dim_product p
    ON f.product_key = p.product_key
GROUP BY p.product_id, p.product_name, p.brand
ORDER BY total_sales DESC;


-- Task 31D: Sales by customer
SELECT
    c.customer_id,
    c.full_name,
    c.country,
    c.city,
    SUM(f.net_sales) AS total_sales,
    SUM(f.quantity) AS total_quantity,
    SUM(f.profit) AS total_profit,
    COUNT(DISTINCT f.order_id) AS order_count
FROM fact_order_detail f
JOIN dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_id, c.full_name, c.country, c.city
ORDER BY total_sales DESC;


-- Task 32: Top 10 products by sales
SELECT
    p.product_id,
    p.product_name,
    p.brand,
    SUM(f.net_sales) AS total_sales,
    SUM(f.quantity) AS quantity_sold,
    COUNT(DISTINCT f.order_id) AS order_count
FROM fact_order_detail f
JOIN dim_product p
    ON f.product_key = p.product_key
GROUP BY p.product_id, p.product_name, p.brand
ORDER BY total_sales DESC
LIMIT 10;


-- Task 33: Top 10 customers by total spending
SELECT
    c.customer_id,
    c.full_name,
    c.country,
    c.city,
    SUM(f.net_sales) AS total_spending,
    COUNT(DISTINCT f.order_id) AS order_count
FROM fact_order_detail f
JOIN dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_id, c.full_name, c.country, c.city
ORDER BY total_spending DESC
LIMIT 10;


-- Task 34: Average order value
-- fact_order is used so each order contributes exactly once.
SELECT
    SUM(net_sales) / NULLIF(COUNT(DISTINCT order_id), 0) AS average_order_value,
    SUM(net_sales) AS total_sales,
    COUNT(DISTINCT order_id) AS total_orders
FROM fact_order;


-- Task 35: Number and value of orders by status
SELECT
    s.order_status,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.net_sales) AS order_value
FROM fact_order o
JOIN dim_order_status s
    ON o.order_status_key = s.order_status_key
GROUP BY s.order_status
ORDER BY order_count DESC;


-- Task 36: Payment-method analysis
SELECT
    m.payment_method,
    COUNT(DISTINCT f.payment_id) AS number_of_transactions,
    SUM(f.amount) AS total_payment_amount,
    AVG(f.amount) AS average_payment_amount
FROM fact_payment f
JOIN dim_payment_method m
    ON f.payment_method_key = m.payment_method_key
GROUP BY m.payment_method
ORDER BY total_payment_amount DESC;


-- Task 37: Shipment performance
SELECT
    COUNT(DISTINCT shipment_id) AS total_shipments,
    AVG(delivery_days) AS average_delivery_days,
    MIN(delivery_days) AS minimum_delivery_days,
    MAX(delivery_days) AS maximum_delivery_days
FROM fact_shipment
WHERE delivery_days IS NOT NULL
  AND delivery_days >= 0;


-- Task 38: Running/cumulative sales by date
WITH daily_sales AS (
    SELECT
        d.full_date,
        SUM(f.net_sales) AS daily_sales
    FROM fact_order_detail f
    JOIN dim_date d
        ON f.date_key = d.date_key
    GROUP BY d.full_date
)
SELECT
    full_date,
    daily_sales,
    SUM(daily_sales) OVER (
        ORDER BY full_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sales
FROM daily_sales
ORDER BY full_date;


-- Task 39: Month-over-month growth
WITH monthly_sales AS (
    SELECT
        d.year,
        d.month,
        d.month_name,
        CAST(CONCAT(
            CAST(d.year AS VARCHAR), '-',
            LPAD(CAST(d.month AS VARCHAR), 2, '0'), '-01'
        ) AS DATE) AS month_start,
        SUM(f.net_sales) AS current_month_sales
    FROM fact_order_detail f
    JOIN dim_date d
        ON f.date_key = d.date_key
    GROUP BY d.year, d.month, d.month_name
), with_previous AS (
    SELECT
        year,
        month,
        month_name,
        month_start,
        current_month_sales,
        LAG(current_month_sales) OVER (
            ORDER BY month_start
        ) AS previous_month_sales
    FROM monthly_sales
)
SELECT
    year,
    month,
    month_name,
    current_month_sales,
    previous_month_sales,
    current_month_sales - COALESCE(previous_month_sales, 0) AS sales_difference,
    CASE
        WHEN previous_month_sales IS NULL OR previous_month_sales = 0 THEN NULL
        ELSE (current_month_sales - previous_month_sales)
             / previous_month_sales * 100
    END AS growth_percentage
FROM with_previous
ORDER BY month_start;


-- Task 40: Top 3 products by sales within each category
WITH product_sales AS (
    SELECT
        c.category_id,
        c.category_name,
        p.product_id,
        p.product_name,
        SUM(f.net_sales) AS sales
    FROM fact_order_detail f
    JOIN dim_product p
        ON f.product_key = p.product_key
    JOIN dim_category c
        ON p.category_key = c.category_key
    GROUP BY
        c.category_id,
        c.category_name,
        p.product_id,
        p.product_name
), ranked_products AS (
    SELECT
        category_id,
        category_name,
        product_id,
        product_name,
        sales,
        RANK() OVER (
            PARTITION BY category_id
            ORDER BY sales DESC
        ) AS product_rank
    FROM product_sales
)
SELECT
    category_id,
    category_name,
    product_id,
    product_name,
    sales,
    product_rank
FROM ranked_products
WHERE product_rank <= 3
ORDER BY category_id, product_rank, sales DESC;


-- Task 41: Customer ranking by total spending
WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.full_name,
        SUM(f.net_sales) AS total_spending,
        COUNT(DISTINCT f.order_id) AS order_count
    FROM fact_order_detail f
    JOIN dim_customer c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_id, c.full_name
)
SELECT
    customer_id,
    full_name,
    total_spending,
    order_count,
    RANK() OVER (
        ORDER BY total_spending DESC
    ) AS customer_rank
FROM customer_sales
ORDER BY customer_rank, customer_id;


-- ============================================================
-- Recommended validation queries before submitting results
-- ============================================================

-- Check 1: fact totals must reconcile
SELECT 'detail' AS source, SUM(net_sales) AS sales, SUM(profit) AS profit
FROM fact_order_detail
UNION ALL
SELECT 'customer_sales', SUM(sales), SUM(profit)
FROM fact_customer_sales
UNION ALL
SELECT 'product_sales', SUM(net_sales), SUM(profit)
FROM fact_product_sales;

-- Check 2: orphan customer keys in the detail fact
SELECT COUNT(*) AS orphan_customer_rows
FROM fact_order_detail f
LEFT JOIN dim_customer c
    ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

-- Check 3: orphan product keys in the detail fact
SELECT COUNT(*) AS orphan_product_rows
FROM fact_order_detail f
LEFT JOIN dim_product p
    ON f.product_key = p.product_key
WHERE p.product_key IS NULL;

-- Check 4: null foreign keys in the detail fact
SELECT
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS null_customer_keys,
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS null_product_keys,
    SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END) AS null_date_keys
FROM fact_order_detail;
