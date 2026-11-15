-- PURPOSE: Clean and transform the raw dataset

-- 1. CREATE A CLEANED VIEW
CREATE OR REPLACE VIEW cleaned_dataset_dataco_analytics AS
SELECT
    -- Convert identifiers into whole numbers
    CAST(TRIM("Order Id") AS BIGINT) AS order_id,
    CAST(TRIM("Order Item Id") AS BIGINT) AS order_item_id,

    CAST(TRIM("Product Category Id") AS INTEGER) AS product_category_id,
    CAST(TRIM("Department Id") AS INTEGER) AS department_id,

    -- Convert text dates into date-time values
    TO_TIMESTAMP(
        "order date (DateOrders)",
        'MM/DD/YYYY HH24:MI'
    ) AS order_date,

    TO_TIMESTAMP(
        "shipping date (DateOrders)",
        'MM/DD/YYYY HH24:MI'
    ) AS shipping_date,

    -- Clean text fields by removing extra spaces
    TRIM("Delivery Status") AS delivery_status,
    TRIM("Order Status") AS order_status,
    TRIM("Shipping Mode") AS shipping_mode,
    TRIM("Market") AS market,
    TRIM(
        REGEXP_REPLACE("Order Region", '[[:space:]]+', ' ', 'g')
    ) AS order_region,

    TRIM("Customer Segment") AS customer_segment,
    TRIM("Department Name") AS department_name,
    TRIM("Category Name") AS category_name,
    TRIM("Product Name") AS product_name,

    -- Convert shipping days and quantity into whole numbers
    CAST(TRIM("Days for shipping (real)") AS INTEGER)
        AS actual_shipping_days,

    CAST(TRIM("Days for shipment (scheduled)") AS INTEGER)
        AS scheduled_shipping_days,

    CAST(TRIM("Order Item Quantity") AS INTEGER)
        AS item_quantity,

    -- Convert financial fields into numeric values
    CAST(TRIM("Order Item Product Price") AS NUMERIC)
        AS item_product_price,

    CAST(TRIM("Order Item Discount") AS NUMERIC)
        AS item_discount,

    CAST(TRIM("Order Item Discount Rate") AS NUMERIC)
        AS item_discount_rate,

    CAST(TRIM("Sales") AS NUMERIC)
        AS gross_sales,

    CAST(TRIM("Order Item Total") AS NUMERIC)
        AS discounted_item_total,

    CAST(TRIM("Order Profit Per Order") AS NUMERIC)
        AS recorded_profit_value,

    CAST(TRIM("Order Item Profit Ratio") AS NUMERIC)
        AS item_profit_ratio,

    -- 2. IDENTIFY SHIPPING ELIGIBILITY
    CASE
        WHEN TRIM("Delivery Status") = 'Shipping canceled'
        THEN FALSE
        ELSE TRUE
    END AS shipping_eligible,

    -- 3. IDENTIFY ORDERS THAT EXCEEDED THE SHIPPING SCHEDULE
    CASE
        WHEN TRIM("Delivery Status") <> 'Shipping canceled'
         AND CAST(TRIM("Days for shipping (real)") AS INTEGER)
             > CAST(TRIM("Days for shipment (scheduled)") AS INTEGER)
        THEN TRUE
        ELSE FALSE
    END AS exceeded_schedule,

    -- 4. CALCULATE EXCESS SHIPPING DAYS
    CASE
        WHEN TRIM("Delivery Status") = 'Shipping canceled'
        THEN NULL

        WHEN CAST(TRIM("Days for shipping (real)") AS INTEGER)
             > CAST(TRIM("Days for shipment (scheduled)") AS INTEGER)
        THEN
            CAST(TRIM("Days for shipping (real)") AS INTEGER)
            - CAST(TRIM("Days for shipment (scheduled)") AS INTEGER)
        ELSE 0
    END AS excess_shipping_days
FROM raw_dataco_supply_chain;


-- 5. CREATE A PHYSICAL CLEANED TABLE
CREATE TABLE clean_dataco_analytics AS
SELECT *
FROM cleaned_dataset_dataco_analytics;

-- 6. VERIFY THE CLEANED DATA
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT order_item_id) AS distinct_order_items
FROM clean_dataco_analytics;

-- 7. VERIFY SHIPPING ELIGIBILITY
SELECT
    shipping_eligible,
    COUNT(*) AS item_records
FROM clean_dataco_analytics
GROUP BY shipping_eligible
ORDER BY shipping_eligible;