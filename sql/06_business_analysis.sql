--Purpose: Business-focused queries used to examine shipment timing and order fulfillment.

-- 1. OVERALL SHIPPING PERFORMANCE
-- One row in fact_order_shipping represents one order.
SELECT
    COUNT(*) AS total_orders,

    SUM(CASE
        WHEN is_shipping_eligible = TRUE THEN 1
        ELSE 0
    END) AS eligible_orders,

    SUM(CASE
        WHEN is_shipping_eligible = TRUE
         AND is_schedule_miss = TRUE THEN 1
        ELSE 0
    END) AS schedule_miss_orders,

    SUM(CASE
        WHEN is_shipping_eligible = FALSE THEN 1
        ELSE 0
    END) AS shipping_canceled_orders,

    ROUND(
        100.0 * SUM(CASE
            WHEN is_shipping_eligible = TRUE
             AND is_schedule_miss = TRUE THEN 1
            ELSE 0
        END)
        / NULLIF(
            SUM(CASE
                WHEN is_shipping_eligible = TRUE THEN 1
                ELSE 0
            END),
            0
        ),
        2
    ) AS schedule_miss_rate

FROM fact_order_shipping;


-- 2. SHIPPING PERFORMANCE BY SHIPPING MODE
-- Uses the prepared order-level aggregate table.
SELECT
    shipping_mode,
    total_orders,
    shipping_canceled_orders,
    eligible_orders,
    orders_over_schedule,
    over_schedule_pct
FROM agg_shipping_mode_summary
ORDER BY over_schedule_pct DESC, eligible_orders DESC;


-- 3. MONTHLY SHIPPING PERFORMANCE
-- Uses one row per month from the monthly aggregate table.
SELECT
    order_month,
    total_orders,
    shipping_canceled_orders,
    eligible_orders,
    orders_over_schedule,
    over_schedule_pct,
    eligible_gross_sales
FROM agg_monthly_shipping_summary
ORDER BY order_month;


-- 4. SHIPPING PERFORMANCE BY MARKET AND REGION
SELECT
    market,
    order_region,
    total_orders,
    shipping_canceled_orders,
    eligible_orders,
    orders_over_schedule,
    over_schedule_pct
FROM agg_geography_shipping_summary
ORDER BY over_schedule_pct DESC, eligible_orders DESC;


-- 5. REGIONAL SCHEDULE-MISS RATE BY SHIPPING MODE
-- Supports the cross-segment analysis matrix.
-- COUNT(*) is the eligible-order count because canceled orders are filtered out.
SELECT
    order_region,
    shipping_mode,

    COUNT(*) AS eligible_orders,

    SUM(CASE
        WHEN is_schedule_miss = TRUE THEN 1
        ELSE 0
    END) AS schedule_miss_orders,

    ROUND(
        100.0 * SUM(CASE
            WHEN is_schedule_miss = TRUE THEN 1
            ELSE 0
        END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS schedule_miss_rate

FROM fact_order_shipping
WHERE is_shipping_eligible = TRUE
GROUP BY
    order_region,
    shipping_mode
ORDER BY
    order_region,
    shipping_mode;


-- 6. SHIPPING PERFORMANCE BY PRODUCT CATEGORY
-- The aggregate is grouped by both department and category.
SELECT
    department_name,
    category_name,
    orders_with_category,
    eligible_orders,
    orders_over_schedule,
    over_schedule_pct,
    eligible_gross_sales
FROM agg_category_shipping_summary
ORDER BY over_schedule_pct DESC, eligible_orders DESC;


-- 7. ORDER-STATUS DISTRIBUTION
-- These are the three columns in agg_order_status_summary.
-- The percentage denominator includes all orders, including canceled shipments.
SELECT
    order_status,
    total_orders,
    percentage_of_orders
FROM agg_order_status_summary
ORDER BY total_orders DESC;


-- 8. DISTRIBUTION OF OVERRUN SEVERITY
-- Shows the number of days by which schedule-miss orders exceeded
-- their scheduled shipping duration.
SELECT
    overrun_days,
    COUNT(*) AS schedule_miss_orders,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS percentage_of_schedule_miss_orders

FROM fact_order_shipping
WHERE is_shipping_eligible = TRUE
  AND is_schedule_miss = TRUE
GROUP BY overrun_days
ORDER BY overrun_days;


-- 9. AVERAGE OVERRUN DAYS BY SHIPPING MODE
SELECT
    shipping_mode,
    COUNT(*) AS schedule_miss_orders,
    ROUND(AVG(overrun_days)::NUMERIC, 2) AS average_overrun_days
FROM fact_order_shipping
WHERE is_shipping_eligible = TRUE
  AND is_schedule_miss = TRUE
GROUP BY shipping_mode
ORDER BY average_overrun_days DESC;


-- 10. RECORDED ORDER-ITEM VALUE BY SHIPPING PERFORMANCE
-- This compares the recorded order_item_total field. It does not estimate
-- financial loss, delayed revenue, or profit caused by schedule misses.
SELECT
    CASE
        WHEN is_schedule_miss = TRUE THEN 'Exceeded Schedule'
        ELSE 'Within Schedule'
    END AS shipping_performance,

    COUNT(*) AS eligible_orders,

    ROUND(SUM(order_item_total), 2)
        AS total_recorded_order_item_value,

    ROUND(AVG(order_item_total), 2)
        AS average_recorded_value_per_order

FROM fact_order_shipping
WHERE is_shipping_eligible = TRUE
GROUP BY
    CASE
        WHEN is_schedule_miss = TRUE THEN 'Exceeded Schedule'
        ELSE 'Within Schedule'
    END
ORDER BY shipping_performance;


-- 11. TOP REGIONS BY SCHEDULE-MISS ORDER VOLUME
SELECT
    order_region,
    COUNT(*) AS schedule_miss_orders
FROM fact_order_shipping
WHERE is_shipping_eligible = TRUE
  AND is_schedule_miss = TRUE
GROUP BY order_region
ORDER BY schedule_miss_orders DESC
LIMIT 10;


-- 12. TOP DEPARTMENT-CATEGORY GROUPS BY SCHEDULE-MISS ORDER VOLUME
-- Uses the category aggregate table so the output follows the same
-- department + category grouping as the category summary.
SELECT
    department_name,
    category_name,
    orders_with_category,
    eligible_orders,
    orders_over_schedule,
    over_schedule_pct,
    eligible_gross_sales
FROM agg_category_shipping_summary
ORDER BY orders_over_schedule DESC, eligible_orders DESC
LIMIT 10;
