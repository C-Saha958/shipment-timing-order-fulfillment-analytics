-- PURPOSE: Create order-level and order-item-level fact tables

-- 1. ORDER-LEVEL SHIPPING FACT TABLE

DROP TABLE IF EXISTS fact_order_shipping;

CREATE TABLE fact_order_shipping AS

SELECT
    order_id,
    order_date,
    shipping_date,
    actual_shipping_days,
    scheduled_shipping_days,
    delivery_status,
    order_status,
    order_region,
    market,
    shipping_mode,

    order_item_count,
    order_item_total,

    actual_shipping_days - scheduled_shipping_days
        AS schedule_variance_days,

    shipping_eligible AS is_sla_eligible,

    exceeded_schedule AS is_schedule_miss,

    CASE
        WHEN exceeded_schedule = TRUE
        THEN excess_shipping_days
        ELSE NULL
    END AS overrun_days

FROM (
    SELECT
        order_id,

        MAX(order_date) AS order_date,
        MAX(shipping_date) AS shipping_date,

        MAX(actual_shipping_days) AS actual_shipping_days,
        MAX(scheduled_shipping_days) AS scheduled_shipping_days,

        MAX(delivery_status) AS delivery_status,
        MAX(order_status) AS order_status,
        MAX(order_region) AS order_region,
        MAX(market) AS market,
        MAX(shipping_mode) AS shipping_mode,

        MAX(shipping_eligible::INTEGER)::BOOLEAN
            AS shipping_eligible,

        MAX(exceeded_schedule::INTEGER)::BOOLEAN
            AS exceeded_schedule,

        MAX(excess_shipping_days) AS excess_shipping_days,

        COUNT(*) AS order_item_count,

        SUM(discounted_item_total) AS order_item_total

    FROM clean_dataco_analytics

    GROUP BY order_id
) AS order_level;


-- 2. ORDER-ITEM-LEVEL FACT TABLE

DROP TABLE IF EXISTS fact_order_item;

CREATE TABLE fact_order_item AS

SELECT
    order_item_id,
    order_id,
    product_category_id,
    category_name,
    department_id,
    department_name,
    product_name,
    item_quantity AS order_item_quantity,
    discounted_item_total AS order_item_total

FROM clean_dataco_analytics;


-- Add primary and supporting keys

ALTER TABLE fact_order_shipping
ADD PRIMARY KEY (order_id);

ALTER TABLE fact_order_item
ADD PRIMARY KEY (order_item_id);

CREATE INDEX idx_fact_order_item_order_id
ON fact_order_item (order_id);


-- Verify order-level fact table

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,

    SUM(CASE
        WHEN is_sla_eligible THEN 1 ELSE 0
    END) AS eligible_orders,

    SUM(CASE
        WHEN is_schedule_miss THEN 1 ELSE 0
    END) AS schedule_miss_orders,

    SUM(CASE
        WHEN NOT is_sla_eligible THEN 1 ELSE 0
    END) AS canceled_orders

FROM fact_order_shipping;


-- Verify order-item-level fact table

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_item_id) AS distinct_item_ids,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM fact_order_item;