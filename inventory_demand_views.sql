-- =========================================================
-- Inventory Demand Forecasting & Reorder Planning
-- Author: Nura Alam Shohag
-- Database: PostgreSQL
-- Description:
--   Creates all reporting views used by the Power BI dashboard
-- =========================================================


-- =========================================================
-- 1. Monthly SKU Demand Aggregation
-- =========================================================

CREATE OR REPLACE VIEW vw_monthly_sku_demand AS
SELECT
    p.product_sku,
    p.product_name,
    DATE_TRUNC('month', f.order_date) AS sales_month,
    SUM(f.order_quantity) AS total_quantity_sold
FROM fact_sales f
JOIN dim_product p
    ON f.product_key = p.product_key
GROUP BY
    p.product_sku,
    p.product_name,
    DATE_TRUNC('month', f.order_date);

-- =========================================================
-- 2. Rolling 3-Month Demand
-- =========================================================

CREATE OR REPLACE VIEW vw_sku_rolling_demand AS 
SELECT 
	product_sku,
	product_name,
	sales_month,
	total_quantity_sold,
	AVG(total_quantity_sold) OVER (
		PARTITION BY product_sku
		ORDER BY sales_month
		ROWS BETWEEN 2 PRECEDING AND CURRENT ROW 
	) AS avg_3_month_demand
FROM vw_monthly_sku_demand; 

-- =========================================================
-- 3. Inventory Planning Assumptions
-- =========================================================

CREATE OR REPLACE VIEW vw_inventory_assumptions AS
SELECT
    product_sku,
    product_name,
    sales_month,
    avg_3_month_demand,
    avg_3_month_demand * 2 AS estimated_inventory_units,
    avg_3_month_demand * 1.5 AS safety_stock_units
FROM vw_sku_rolling_demand;

-- =========================================================
-- 4. Inventory Demand Signal Classification
-- =========================================================

CREATE OR REPLACE VIEW vw_sku_inventory_signal AS
SELECT
    product_sku,
    product_name,
    sales_month,
    total_quantity_sold,
    avg_3_month_demand,
    CASE
        WHEN total_quantity_sold > avg_3_month_demand * 1.2 THEN 'High Demand'
        WHEN total_quantity_sold < avg_3_month_demand * 0.8 THEN 'Low Demand'
        ELSE 'Stable'
    END AS demand_signal
FROM vw_sku_rolling_demand;
