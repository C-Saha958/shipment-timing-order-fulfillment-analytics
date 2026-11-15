-- PURPOSE: Create the raw dataset table

CREATE TABLE raw_dataco_supply_chain (
    "Type" TEXT,
    "Days for shipping (real)" TEXT,
    "Days for shipment (scheduled)" TEXT,
    "Benefit per order" TEXT,
    "Sales per customer" TEXT,
    "Delivery Status" TEXT,
    "Late_delivery_risk" TEXT,
    "Category Id" TEXT,
    "Category Name" TEXT,
    "Customer City" TEXT,
    "Customer Country" TEXT,
    "Customer Email" TEXT,
    "Customer Fname" TEXT,
    "Customer Id" TEXT,
    "Customer Lname" TEXT,
    "Customer Password" TEXT,
    "Customer Segment" TEXT,
    "Customer State" TEXT,
    "Customer Street" TEXT,
    "Customer Zipcode" TEXT,
    "Department Id" TEXT,
    "Department Name" TEXT,
    "Latitude" TEXT,
    "Longitude" TEXT,
    "Market" TEXT,
    "Order City" TEXT,
    "Order Country" TEXT,
    "Order Customer Id" TEXT,
    "order date (DateOrders)" TEXT,
    "Order Id" TEXT,
    "Order Item Cardprod Id" TEXT,
    "Order Item Discount" TEXT,
    "Order Item Discount Rate" TEXT,
    "Order Item Id" TEXT,
    "Order Item Product Price" TEXT,
    "Order Item Profit Ratio" TEXT,
    "Order Item Quantity" TEXT,
    "Sales" TEXT,
    "Order Item Total" TEXT,
    "Order Profit Per Order" TEXT,
    "Order Region" TEXT,
    "Order State" TEXT,
    "Order Status" TEXT,
    "Order Zipcode" TEXT,
    "Product Card Id" TEXT,
    "Product Category Id" TEXT,
    "Product Description" TEXT,
    "Product Image" TEXT,
    "Product Name" TEXT,
    "Product Price" TEXT,
    "Product Status" TEXT,
    "shipping date (DateOrders)" TEXT,
    "Shipping Mode" TEXT
);

-- Verify successful data import
SELECT
    COUNT(*) AS total_rows
FROM raw_dataco_supply_chain;

-- Verify the number of imported columns
SELECT
    COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND table_name = 'raw_dataco_supply_chain';