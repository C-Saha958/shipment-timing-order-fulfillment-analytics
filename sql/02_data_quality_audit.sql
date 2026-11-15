-- PURPOSE: Inspect dataset structure, completeness and consistency


-- 1. CHECK DATASET SIZE AND ORDER-ITEM GRAIN

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT "Order Id") AS distinct_orders,
    COUNT(DISTINCT "Order Item Id") AS distinct_order_items
FROM raw_dataco_supply_chain;


-- 2. CHECK FOR MISSING IDENTIFIERS

SELECT
    SUM(CASE
        WHEN "Order Id" IS NULL OR TRIM("Order Id") = ''
        THEN 1 ELSE 0
    END) AS missing_order_ids,

    SUM(CASE
        WHEN "Order Item Id" IS NULL OR TRIM("Order Item Id") = ''
        THEN 1 ELSE 0
    END) AS missing_order_item_ids

FROM raw_dataco_supply_chain;


-- 3. CHECK FOR EXACT DUPLICATE RECORDS

SELECT
    COUNT(*) AS exact_duplicate_groups
FROM (
    SELECT
        COUNT(*) AS occurrences
    FROM raw_dataco_supply_chain
    GROUP BY
        "Type",
        "Days for shipping (real)",
        "Days for shipment (scheduled)",
        "Benefit per order",
        "Sales per customer",
        "Delivery Status",
        "Late_delivery_risk",
        "Category Id",
        "Category Name",
        "Customer City",
        "Customer Country",
        "Customer Email",
        "Customer Fname",
        "Customer Id",
        "Customer Lname",
        "Customer Password",
        "Customer Segment",
        "Customer State",
        "Customer Street",
        "Customer Zipcode",
        "Department Id",
        "Department Name",
        "Latitude",
        "Longitude",
        "Market",
        "Order City",
        "Order Country",
        "Order Customer Id",
        "order date (DateOrders)",
        "Order Id",
        "Order Item Cardprod Id",
        "Order Item Discount",
        "Order Item Discount Rate",
        "Order Item Id",
        "Order Item Product Price",
        "Order Item Profit Ratio",
        "Order Item Quantity",
        "Sales",
        "Order Item Total",
        "Order Profit Per Order",
        "Order Region",
        "Order State",
        "Order Status",
        "Order Zipcode",
        "Product Card Id",
        "Product Category Id",
        "Product Description",
        "Product Image",
        "Product Name",
        "Product Price",
        "Product Status",
        "shipping date (DateOrders)",
        "Shipping Mode"
    HAVING COUNT(*) > 1
) AS duplicate_groups;


-- 4. CHECK DELIVERY STATUS DISTRIBUTION

SELECT
    TRIM("Delivery Status") AS delivery_status,
    COUNT(*) AS item_records
FROM raw_dataco_supply_chain
GROUP BY TRIM("Delivery Status")
ORDER BY item_records DESC;


-- 5. CHECK SHIPPING MODE DISTRIBUTION

SELECT
    TRIM("Shipping Mode") AS shipping_mode,
    COUNT(*) AS item_records
FROM raw_dataco_supply_chain
GROUP BY TRIM("Shipping Mode")
ORDER BY item_records DESC;


-- 6. CHECK SCHEDULED SHIPPING DAYS FOR EACH MODE

SELECT
    TRIM("Shipping Mode") AS shipping_mode,
    "Days for shipment (scheduled)" AS scheduled_days,
    COUNT(*) AS item_records
FROM raw_dataco_supply_chain
GROUP BY
    TRIM("Shipping Mode"),
    "Days for shipment (scheduled)"
ORDER BY
    shipping_mode,
    scheduled_days;


-- 7. CHECK WHETHER SHIPPING DETAILS ARE CONSISTENT
--    WITHIN EACH ORDER

SELECT
    COUNT(*) AS total_orders,

    SUM(CASE
        WHEN region_count > 1 THEN 1 ELSE 0
    END) AS orders_with_multiple_regions,

    SUM(CASE
        WHEN mode_count > 1 THEN 1 ELSE 0
    END) AS orders_with_multiple_shipping_modes,

    SUM(CASE
        WHEN actual_days_count > 1 THEN 1 ELSE 0
    END) AS orders_with_multiple_actual_days,

    SUM(CASE
        WHEN scheduled_days_count > 1 THEN 1 ELSE 0
    END) AS orders_with_multiple_scheduled_days,

    SUM(CASE
        WHEN delivery_status_count > 1 THEN 1 ELSE 0
    END) AS orders_with_multiple_delivery_statuses

FROM (
    SELECT
        "Order Id",

        COUNT(DISTINCT "Order Region") AS region_count,
        COUNT(DISTINCT "Shipping Mode") AS mode_count,
        COUNT(DISTINCT "Days for shipping (real)") AS actual_days_count,
        COUNT(DISTINCT "Days for shipment (scheduled)") AS scheduled_days_count,
        COUNT(DISTINCT "Delivery Status") AS delivery_status_count

    FROM raw_dataco_supply_chain
    GROUP BY "Order Id"
) AS order_check;


-- 8. CHECK THE DATASET DATE RANGE

SELECT
    CAST(
        MIN(
            TO_TIMESTAMP(
                "order date (DateOrders)",
                'MM/DD/YYYY HH24:MI'
            )
        ) AS DATE
    ) AS first_order_date,

    CAST(
        MAX(
            TO_TIMESTAMP(
                "order date (DateOrders)",
                'MM/DD/YYYY HH24:MI'
            )
        ) AS DATE
    ) AS last_order_date

FROM raw_dataco_supply_chain;


-- 9. CHECK CATEGORY NAME CONSISTENCY

SELECT
    COUNT(DISTINCT "Category Name") AS original_categories,
    COUNT(DISTINCT TRIM("Category Name")) AS cleaned_categories
FROM raw_dataco_supply_chain;


-- 10. CHECK RELATIONSHIPS BETWEEN FINANCIAL FIELDS

SELECT
    COUNT(*) AS total_records,

    SUM(CASE
        WHEN ROUND(CAST("Sales" AS NUMERIC), 2)
          <> ROUND(
              CAST("Order Item Product Price" AS NUMERIC)
              * CAST("Order Item Quantity" AS NUMERIC),
              2
          )
        THEN 1 ELSE 0
    END) AS sales_calculation_mismatches,

    SUM(CASE
        WHEN ROUND(CAST("Order Item Total" AS NUMERIC), 2)
          <> ROUND(
              CAST("Sales" AS NUMERIC)
              - CAST("Order Item Discount" AS NUMERIC),
              2
          )
        THEN 1 ELSE 0
    END) AS item_total_calculation_mismatches

FROM raw_dataco_supply_chain;