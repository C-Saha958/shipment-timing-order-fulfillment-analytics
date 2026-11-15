/*
--Project: DataCo Shipment Timing & Order Fulfillment Performance Analytics

--Purpose: Create the five aggregate tables used as Power BI data sources.

Grain:
- Monthly, shipping-mode, geography, and order-status summaries: grouped order counts.
- Category summary: one row per department and category. An order containing
  items from multiple categories is counted once in each relevant category.

All shipment schedule-miss percentages use eligible (non-canceled) orders as
 the denominator. "Schedule miss" means actual shipping days exceeded the
 scheduled shipping days; it is not a confirmed contractual SLA breach.
*/

-- 1. Monthly shipment performance.
-- Source Sales is retained as eligible_gross_sales at item-row grain.
CREATE TABLE agg_monthly_shipping_summary AS
SELECT
    DATE_TRUNC('month', order_date)::DATE AS order_month,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT CASE
        WHEN is_shipping_eligible = FALSE THEN order_id
    END) AS shipping_canceled_orders,
    COUNT(DISTINCT CASE
        WHEN is_shipping_eligible = TRUE THEN order_id
    END) AS eligible_orders,
    COUNT(DISTINCT CASE
        WHEN is_shipping_eligible = TRUE AND is_schedule_miss = TRUE THEN order_id
    END) AS orders_over_schedule,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN is_shipping_eligible = TRUE AND is_schedule_miss = TRUE THEN order_id
        END)
        / NULLIF(COUNT(DISTINCT CASE
            WHEN is_shipping_eligible = TRUE THEN order_id
        END), 0),
        2
    ) AS over_schedule_pct,
    ROUND(SUM(CASE
        WHEN is_shipping_eligible = TRUE THEN gross_sales
        ELSE 0
    END), 2) AS eligible_gross_sales
FROM clean_dataco_analytics
GROUP BY DATE_TRUNC('month', order_date)::DATE;

-- 2. Shipping-mode performance.
CREATE TABLE agg_shipping_mode_summary AS
SELECT
    shipping_mode,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN is_shipping_eligible = FALSE THEN 1 ELSE 0 END)
        AS shipping_canceled_orders,
    SUM(CASE WHEN is_shipping_eligible = TRUE THEN 1 ELSE 0 END)
        AS eligible_orders,
    SUM(CASE
        WHEN is_shipping_eligible = TRUE AND is_schedule_miss = TRUE THEN 1
        ELSE 0
    END) AS orders_over_schedule,
    ROUND(
        100.0 * SUM(CASE
            WHEN is_shipping_eligible = TRUE AND is_schedule_miss = TRUE THEN 1
            ELSE 0
        END)
        / NULLIF(SUM(CASE WHEN is_shipping_eligible = TRUE THEN 1 ELSE 0 END), 0),
        2
    ) AS over_schedule_pct
FROM fact_order_shipping
GROUP BY shipping_mode;

-- 3. Market and region performance.
CREATE TABLE agg_geography_shipping_summary AS
SELECT
    market,
    order_region,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN is_shipping_eligible = FALSE THEN 1 ELSE 0 END)
        AS shipping_canceled_orders,
    SUM(CASE WHEN is_shipping_eligible = TRUE THEN 1 ELSE 0 END)
        AS eligible_orders,
    SUM(CASE
        WHEN is_shipping_eligible = TRUE AND is_schedule_miss = TRUE THEN 1
        ELSE 0
    END) AS orders_over_schedule,
    ROUND(
        100.0 * SUM(CASE
            WHEN is_shipping_eligible = TRUE AND is_schedule_miss = TRUE THEN 1
            ELSE 0
        END)
        / NULLIF(SUM(CASE WHEN is_shipping_eligible = TRUE THEN 1 ELSE 0 END), 0),
        2
    ) AS over_schedule_pct
FROM fact_order_shipping
GROUP BY market, order_region;

-- 4. Category performance.
-- The output columns match the category aggregate CSV structure:
-- department_name, category_name, orders_with_category, eligible_orders,
-- orders_over_schedule, over_schedule_pct, eligible_gross_sales.
-- gross_sales comes from the source Sales field retained in fact_order_item.
CREATE TABLE agg_category_shipping_summary AS
SELECT
    fi.department_name,
    fi.category_name,
    COUNT(DISTINCT fi.order_id) AS orders_with_category,
    COUNT(DISTINCT CASE
        WHEN fs.is_shipping_eligible = TRUE THEN fi.order_id
    END) AS eligible_orders,
    COUNT(DISTINCT CASE
        WHEN fs.is_shipping_eligible = TRUE AND fs.is_schedule_miss = TRUE
        THEN fi.order_id
    END) AS orders_over_schedule,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN fs.is_shipping_eligible = TRUE AND fs.is_schedule_miss = TRUE
            THEN fi.order_id
        END)
        / NULLIF(COUNT(DISTINCT CASE
            WHEN fs.is_shipping_eligible = TRUE THEN fi.order_id
        END), 0),
        2
    ) AS over_schedule_pct,
    ROUND(SUM(CASE
        WHEN fs.is_shipping_eligible = TRUE THEN fi.gross_sales
        ELSE 0
    END), 2) AS eligible_gross_sales
FROM fact_order_item AS fi
JOIN fact_order_shipping AS fs
    ON fi.order_id = fs.order_id
GROUP BY
    fi.department_name,
    fi.category_name;

-- 5. Order-status distribution.
-- The output columns match the order-status aggregate CSV structure:
-- order_status, total_orders, percentage_of_orders.
-- Percentage is calculated across all orders, including canceled shipments.
CREATE TABLE agg_order_status_summary AS
SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS percentage_of_orders
FROM fact_order_shipping
GROUP BY order_status;

-- Preview all five summaries after creation.
SELECT * FROM agg_monthly_shipping_summary ORDER BY order_month;
SELECT * FROM agg_shipping_mode_summary ORDER BY over_schedule_pct DESC;
SELECT * FROM agg_geography_shipping_summary ORDER BY over_schedule_pct DESC;
SELECT * FROM agg_category_shipping_summary ORDER BY over_schedule_pct DESC;
SELECT * FROM agg_order_status_summary ORDER BY total_orders DESC;