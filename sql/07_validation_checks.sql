-- PURPOSE:
-- Validate the final fact tables, KPI calculations,
-- aggregate table totals and data consistency.

-- 1. VALIDATE ORDER-LEVEL DATA GRAIN
-- Each row in fact_order_shipping should represent one order.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(order_id) - COUNT(DISTINCT order_id) AS duplicate_order_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS missing_order_ids
FROM fact_order_shipping;


-- 2. VALIDATE ORDER ELIGIBILITY AND SCHEDULE MISSES
-- Canceled orders are excluded from the eligible-order denominator.
SELECT
    COUNT(*) AS total_orders,

    SUM(CASE WHEN is_sla_eligible = TRUE THEN 1 ELSE 0 END)
        AS eligible_orders,

    SUM(CASE WHEN is_schedule_miss = TRUE THEN 1 ELSE 0 END)
        AS schedule_miss_orders,

    SUM(CASE WHEN is_sla_eligible = FALSE THEN 1 ELSE 0 END)
        AS canceled_orders,

    SUM(CASE WHEN is_sla_eligible IS NULL THEN 1 ELSE 0 END)
        AS missing_eligibility_flags,

    SUM(CASE WHEN is_schedule_miss IS NULL THEN 1 ELSE 0 END)
        AS missing_schedule_miss_flags,

    SUM(CASE
        WHEN is_schedule_miss = TRUE AND is_sla_eligible = FALSE THEN 1
        ELSE 0
    END) AS schedule_misses_in_ineligible_orders,

    ROUND(
        100.0 * SUM(CASE WHEN is_schedule_miss = TRUE THEN 1 ELSE 0 END)
        / NULLIF(
            SUM(CASE WHEN is_sla_eligible = TRUE THEN 1 ELSE 0 END),
            0
        ),
        2
    ) AS schedule_miss_rate

FROM fact_order_shipping;


-- 3. VALIDATE SCHEDULE VARIANCE CALCULATION
-- Schedule variance = actual shipping days - scheduled shipping days.

SELECT
    COUNT(*) AS eligible_orders_checked,

    SUM(CASE
        WHEN actual_shipping_days IS NULL
          OR scheduled_shipping_days IS NULL
          OR schedule_variance_days IS NULL
          OR schedule_variance_days <> (actual_shipping_days - scheduled_shipping_days)
        THEN 1
        ELSE 0
    END) AS variance_mismatch_orders,

    SUM(CASE WHEN schedule_variance_days > 0 THEN 1 ELSE 0 END)
        AS orders_over_schedule,

    SUM(CASE WHEN schedule_variance_days = 0 THEN 1 ELSE 0 END)
        AS orders_on_schedule,

    SUM(CASE WHEN schedule_variance_days < 0 THEN 1 ELSE 0 END)
        AS orders_under_schedule

FROM fact_order_shipping
WHERE is_sla_eligible = TRUE;


-- 4. VALIDATE THE SCHEDULE-MISS FLAG
-- A schedule miss should be TRUE when schedule variance is above zero.

SELECT
    COUNT(*) AS eligible_orders_checked,

    SUM(CASE
        WHEN schedule_variance_days IS NULL
          OR is_schedule_miss IS NULL
          OR is_schedule_miss <> (schedule_variance_days > 0)
        THEN 1
        ELSE 0
    END) AS schedule_flag_mismatch_orders

FROM fact_order_shipping
WHERE is_sla_eligible = TRUE;


-- 5. VALIDATE OVERRUN DAYS
-- Missed orders should have positive overrun days equal to schedule variance.
-- Orders without a schedule miss should have NULL overrun days.
SELECT
    COUNT(*) AS total_orders,

    SUM(CASE
        WHEN is_schedule_miss = TRUE
         AND (
             overrun_days IS NULL
             OR overrun_days <= 0
             OR overrun_days <> schedule_variance_days
         )
        THEN 1
        ELSE 0
    END) AS invalid_overrun_records,

    SUM(CASE
        WHEN is_schedule_miss = FALSE AND overrun_days IS NOT NULL THEN 1
        ELSE 0
    END) AS unexpected_overrun_records

FROM fact_order_shipping;


-- 6. VALIDATE AVERAGE OVERRUN DAYS BY SHIPPING MODE

SELECT
    shipping_mode,
    COUNT(*) AS schedule_miss_orders,
    MIN(overrun_days) AS minimum_overrun_days,
    MAX(overrun_days) AS maximum_overrun_days,
    ROUND(AVG(overrun_days)::NUMERIC, 2) AS average_overrun_days

FROM fact_order_shipping
WHERE is_sla_eligible = TRUE
  AND is_schedule_miss = TRUE
GROUP BY shipping_mode
ORDER BY average_overrun_days DESC;


-- 7. VALIDATE SHIPPING MODE AGGREGATE TOTALS
-- The two summary sections below are combined into one result row.

WITH fact_totals AS (
    SELECT
        SUM(CASE WHEN is_sla_eligible = TRUE THEN 1 ELSE 0 END)
            AS fact_eligible_orders,
        SUM(CASE WHEN is_schedule_miss = TRUE THEN 1 ELSE 0 END)
            AS fact_schedule_miss_orders,
        SUM(CASE WHEN is_sla_eligible = FALSE THEN 1 ELSE 0 END)
            AS fact_canceled_orders
    FROM fact_order_shipping
),
aggregate_totals AS (
    SELECT
        SUM(eligible_orders) AS aggregate_eligible_orders,
        SUM(orders_over_schedule) AS aggregate_schedule_miss_orders,
        SUM(shipping_canceled_orders) AS aggregate_canceled_orders
    FROM agg_shipping_mode_summary
)
SELECT
    fact_eligible_orders,
    aggregate_eligible_orders,
    fact_schedule_miss_orders,
    aggregate_schedule_miss_orders,
    fact_canceled_orders,
    aggregate_canceled_orders
FROM fact_totals
CROSS JOIN aggregate_totals;


-- 8. VALIDATE MONTHLY AGGREGATE TOTALS

WITH fact_totals AS (
    SELECT
        SUM(CASE WHEN is_sla_eligible = TRUE THEN 1 ELSE 0 END)
            AS fact_eligible_orders,
        SUM(CASE WHEN is_schedule_miss = TRUE THEN 1 ELSE 0 END)
            AS fact_schedule_miss_orders,
        SUM(CASE WHEN is_sla_eligible = FALSE THEN 1 ELSE 0 END)
            AS fact_canceled_orders
    FROM fact_order_shipping
),
aggregate_totals AS (
    SELECT
        SUM(eligible_orders) AS aggregate_eligible_orders,
        SUM(orders_over_schedule) AS aggregate_schedule_miss_orders,
        SUM(shipping_canceled_orders) AS aggregate_canceled_orders
    FROM agg_monthly_shipping_summary
)
SELECT
    fact_eligible_orders,
    aggregate_eligible_orders,
    fact_schedule_miss_orders,
    aggregate_schedule_miss_orders,
    fact_canceled_orders,
    aggregate_canceled_orders
FROM fact_totals
CROSS JOIN aggregate_totals;


-- 9. VALIDATE GEOGRAPHICAL AGGREGATE TOTALS

WITH fact_totals AS (
    SELECT
        SUM(CASE WHEN is_sla_eligible = TRUE THEN 1 ELSE 0 END)
            AS fact_eligible_orders,
        SUM(CASE WHEN is_schedule_miss = TRUE THEN 1 ELSE 0 END)
            AS fact_schedule_miss_orders,
        SUM(CASE WHEN is_sla_eligible = FALSE THEN 1 ELSE 0 END)
            AS fact_canceled_orders
    FROM fact_order_shipping
),
aggregate_totals AS (
    SELECT
        SUM(eligible_orders) AS aggregate_eligible_orders,
        SUM(orders_over_schedule) AS aggregate_schedule_miss_orders,
        SUM(shipping_canceled_orders) AS aggregate_canceled_orders
    FROM agg_geography_shipping_summary
)
SELECT
    fact_eligible_orders,
    aggregate_eligible_orders,
    fact_schedule_miss_orders,
    aggregate_schedule_miss_orders,
    fact_canceled_orders,
    aggregate_canceled_orders
FROM fact_totals
CROSS JOIN aggregate_totals;


-- 10. VALIDATE CATEGORY AGGREGATE TOTALS
-- Category order counts are associations, not unique company-wide order totals.
-- One order can contain items from more than one category.

SELECT
    COUNT(*) AS department_category_combinations,
    SUM(orders_with_category) AS category_order_associations,
    SUM(eligible_orders) AS category_eligible_order_associations,
    SUM(orders_over_schedule) AS category_schedule_miss_associations,
    ROUND(SUM(eligible_gross_sales), 2) AS aggregate_eligible_gross_sales
FROM agg_category_shipping_summary;


-- 11. VALIDATE CATEGORY SALES AGAINST RAW SALES
-- The category aggregate uses the source Sales field.

SELECT
    (
        SELECT ROUND(SUM(r."Sales"::NUMERIC), 2)
        FROM raw_dataco_supply_chain AS r
        JOIN fact_order_shipping AS fs
            ON NULLIF(BTRIM(r."Order Id"), '')::BIGINT = fs.order_id
        WHERE fs.is_sla_eligible = TRUE
    ) AS raw_eligible_sales,

    (
        SELECT ROUND(SUM(eligible_gross_sales), 2)
        FROM agg_category_shipping_summary
    ) AS aggregate_eligible_gross_sales;


-- 12. VALIDATE CATEGORY SCHEDULE-MISS PERCENTAGES
-- This query returns only categories with a percentage mismatch.

WITH category_check AS (
    SELECT
        department_name,
        category_name,
        eligible_orders,
        orders_over_schedule,
        over_schedule_pct,
        ROUND(
            100.0 * orders_over_schedule / NULLIF(eligible_orders, 0),
            2
        ) AS recalculated_over_schedule_pct
    FROM agg_category_shipping_summary
)
SELECT *
FROM category_check
WHERE
    (over_schedule_pct IS NULL AND recalculated_over_schedule_pct IS NOT NULL)
    OR (over_schedule_pct IS NOT NULL AND recalculated_over_schedule_pct IS NULL)
    OR (over_schedule_pct <> recalculated_over_schedule_pct);

-- 13. VALIDATE ORDER STATUS AGGREGATE TOTALS
-- This table has three columns: order_status, total_orders, percentage_of_orders.

SELECT
    (SELECT COUNT(*) FROM fact_order_shipping) AS fact_total_orders,
    SUM(total_orders) AS aggregate_total_orders,
    ROUND(SUM(percentage_of_orders), 2) AS summed_order_status_percentage
FROM agg_order_status_summary;


-- 14. VALIDATE ORDER COUNTS BY ORDER STATUS
-- Compare the fact-table count with the aggregate-table count for each status.

WITH fact_status AS (
    SELECT
        order_status,
        COUNT(*) AS fact_total_orders
    FROM fact_order_shipping
    GROUP BY order_status
)
SELECT
    CASE
        WHEN f.order_status IS NULL THEN a.order_status
        ELSE f.order_status
    END AS order_status,

    CASE
        WHEN f.fact_total_orders IS NULL THEN 0
        ELSE f.fact_total_orders
    END AS fact_total_orders,

    CASE
        WHEN a.total_orders IS NULL THEN 0
        ELSE a.total_orders
    END AS aggregate_total_orders,

    CASE
        WHEN f.fact_total_orders IS NULL THEN 0
        ELSE f.fact_total_orders
    END
    -
    CASE
        WHEN a.total_orders IS NULL THEN 0
        ELSE a.total_orders
    END AS order_count_difference

FROM fact_status AS f
FULL OUTER JOIN agg_order_status_summary AS a
    ON f.order_status = a.order_status
ORDER BY order_status;

-- 15. VALIDATE ORDER STATUS PERCENTAGES
-- Displays all statuses so the stored and recalculated values can be compared.

SELECT
    order_status,
    total_orders,
    percentage_of_orders,
    ROUND(
        100.0 * total_orders / NULLIF(SUM(total_orders) OVER (), 0),
        2
    ) AS recalculated_percentage
FROM agg_order_status_summary;


-- 16. VALIDATE SHIPPING MODE KPI PERCENTAGES
-- This query returns only shipping modes with a percentage mismatch.

WITH shipping_mode_check AS (
    SELECT
        shipping_mode,
        eligible_orders,
        orders_over_schedule,
        over_schedule_pct,
        ROUND(
            100.0 * orders_over_schedule / NULLIF(eligible_orders, 0),
            2
        ) AS recalculated_over_schedule_pct
    FROM agg_shipping_mode_summary
)
SELECT *
FROM shipping_mode_check
WHERE
    (over_schedule_pct IS NULL AND recalculated_over_schedule_pct IS NOT NULL)
    OR (over_schedule_pct IS NOT NULL AND recalculated_over_schedule_pct IS NULL)
    OR (over_schedule_pct <> recalculated_over_schedule_pct);

-- 17. VALIDATE MONTHLY KPI PERCENTAGES
-- This query returns only months with a percentage mismatch.

WITH monthly_check AS (
    SELECT
        order_month,
        eligible_orders,
        orders_over_schedule,
        over_schedule_pct,
        ROUND(
            100.0 * orders_over_schedule / NULLIF(eligible_orders, 0),
            2
        ) AS recalculated_over_schedule_pct
    FROM agg_monthly_shipping_summary
)
SELECT *
FROM monthly_check
WHERE
    (over_schedule_pct IS NULL AND recalculated_over_schedule_pct IS NOT NULL)
    OR (over_schedule_pct IS NOT NULL AND recalculated_over_schedule_pct IS NULL)
    OR (over_schedule_pct <> recalculated_over_schedule_pct);

-- 18. VALIDATE GEOGRAPHICAL KPI PERCENTAGES
-- This query returns only market-region rows with a percentage mismatch.

WITH geography_check AS (
    SELECT
        market,
        order_region,
        eligible_orders,
        orders_over_schedule,
        over_schedule_pct,
        ROUND(
            100.0 * orders_over_schedule / NULLIF(eligible_orders, 0),
            2
        ) AS recalculated_over_schedule_pct
    FROM agg_geography_shipping_summary
)
SELECT *
FROM geography_check
WHERE
    (over_schedule_pct IS NULL AND recalculated_over_schedule_pct IS NOT NULL)
    OR (over_schedule_pct IS NOT NULL AND recalculated_over_schedule_pct IS NULL)
    OR (over_schedule_pct <> recalculated_over_schedule_pct);