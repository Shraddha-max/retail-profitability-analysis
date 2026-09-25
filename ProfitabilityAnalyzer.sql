CREATE DATABASE retail_profitability;

USE retail_profitability;

SELECT COUNT(*) FROM analysis_ready;

SELECT COUNT(*) FROM monthly_targets;

SELECT * FROM analysis_ready LIMIT 10;
SELECT * FROM monthly_targets LIMIT 10;

-- Question 1: Is higher discount actually better?
-- Create the following discount groups:
-- Low Discount: 0% to 10%
-- Medium Discount: >10% to 25%
-- High Discount: >25%

-- For each:
-- product_category + discount_group
-- calculate:
-- - Number of distinct orders
-- - Average order value
-- - Realized revenue
-- - Realized profit
-- - Realized margin %
-- - Return rate
-- Determine which product categories show the following pattern:
-- Higher discount generates higher revenue per order but lower realized profit margin.
WITH discount_data AS (
    
    SELECT
        product_category,
        order_id,
        quantity,
        total_return_qty,
        realized_revenue,
        realized_profit,
        discount_pct,

        CASE
            WHEN discount_pct BETWEEN 0 AND 10
                THEN 'Low Discount'

            WHEN discount_pct > 10
                 AND discount_pct <= 25
                THEN 'Medium Discount'

            WHEN discount_pct > 25
                THEN 'High Discount'
        END AS discount_group

    FROM analysis_ready
)

SELECT
    product_category,
    discount_group,

    COUNT(DISTINCT order_id) AS number_of_orders,

    ROUND(
        SUM(realized_revenue)
        / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS average_order_value,

    ROUND(
        SUM(realized_revenue),
        2
    ) AS realized_revenue,

    ROUND(
        SUM(realized_profit),
        2
    ) AS realized_profit,

    ROUND(
        SUM(realized_profit)
        / NULLIF(SUM(realized_revenue), 0)
        * 100,
        2
    ) AS realized_margin_pct,

    ROUND(
        SUM(total_return_qty)
        / NULLIF(SUM(quantity), 0)
        * 100,
        2
    ) AS return_rate

FROM discount_data

GROUP BY
    product_category,
    discount_group

ORDER BY
    product_category,
    CASE discount_group
        WHEN 'Low Discount' THEN 1
        WHEN 'Medium Discount' THEN 2
        WHEN 'High Discount' THEN 3
    END;
    
 --    
-- Question 2: Growth without profitability
-- For each region and month calculate:
-- - Realized revenue
-- - Realized profit
-- - Realized margin %
-- Using a window function, calculate:
-- - Month-on-month revenue growth %
-- - Month-on-month profit growth %
-- Identify all region-month combinations where:
-- Revenue Growth > 0

-- but:
-- Profit Growth < 0

-- Rank them by the size of the revenue increase.    
    
    WITH monthly_data AS (

    SELECT
        region,
        month,

        SUM(realized_revenue) AS realized_revenue,

        SUM(realized_profit) AS realized_profit,

        SUM(realized_profit)
        / NULLIF(SUM(realized_revenue), 0) * 100
        AS realized_margin_pct

    FROM analysis_ready

    GROUP BY
        region,
        month
),

previous_month AS (

    SELECT
        region,
        month,
        realized_revenue,
        realized_profit,
        realized_margin_pct,

        LAG(realized_revenue)
        OVER (
            PARTITION BY region
            ORDER BY month
        ) AS previous_revenue,

        LAG(realized_profit)
        OVER (
            PARTITION BY region
            ORDER BY month
        ) AS previous_profit

    FROM monthly_data
),

growth_calculation AS (

    SELECT
        region,
        month,

        realized_revenue,
        realized_profit,
        realized_margin_pct,

        previous_revenue,
        previous_profit,

        ROUND(
            (realized_revenue - previous_revenue)
            / NULLIF(previous_revenue, 0) * 100,
            2
        ) AS revenue_growth_pct,

        ROUND(
            (realized_profit - previous_profit)
            / NULLIF(previous_profit, 0) * 100,
            2
        ) AS profit_growth_pct,

        ROUND(
            realized_revenue - previous_revenue,
            2
        ) AS revenue_increase

    FROM previous_month
)

SELECT
    region,
    month,

    ROUND(realized_revenue, 2) AS realized_revenue,

    ROUND(realized_profit, 2) AS realized_profit,

    ROUND(realized_margin_pct, 2) AS realized_margin_pct,

    revenue_growth_pct,
    profit_growth_pct,

    revenue_increase

FROM growth_calculation

WHERE
    revenue_growth_pct > 0
    AND profit_growth_pct < 0

ORDER BY
    revenue_increase DESC;
    
    

-- Question 3: High-value customers that may not actually be valuable
-- At customer level calculate:
-- - Total orders
-- - Realized revenue
-- - Realized profit
-- - Realized margin %
-- - Return rate
-- - Average discount %
-- Use SQL window functions to identify customers in the:
-- Top 20% by realized revenue

-- Then identify which of these customers also have:
-- Realized Margin % below company median

-- OR
-- Return Rate above company average

-- Return the top 15 such customers ranked by realized revenue.

WITH customer_metrics AS (

    SELECT
        customer_id,

        COUNT(DISTINCT order_id) AS total_orders,

        SUM(realized_revenue) AS realized_revenue,

        SUM(realized_profit) AS realized_profit,

        SUM(realized_profit)
        / NULLIF(SUM(realized_revenue), 0) * 100
        AS realized_margin_pct,

        SUM(total_return_qty)
        / NULLIF(SUM(quantity), 0) * 100
        AS return_rate,

        AVG(discount_pct) AS average_discount_pct

    FROM analysis_ready

    GROUP BY
        customer_id
),

company_stats AS (

    SELECT

        AVG(return_rate) AS company_average_return_rate,

        (
            SELECT AVG(realized_margin_pct)
            FROM (
                SELECT
                    realized_margin_pct,

                    ROW_NUMBER() OVER (
                        ORDER BY realized_margin_pct
                    ) AS row_num,

                    COUNT(*) OVER () AS total_customers

                FROM customer_metrics
            ) AS median_data

            WHERE row_num IN (
                FLOOR((total_customers + 1) / 2),
                CEIL((total_customers + 1) / 2)
            )
        ) AS company_median_margin

    FROM customer_metrics
),

ranked_customers AS (

    SELECT
        cm.*,

        NTILE(5) OVER (
            ORDER BY realized_revenue DESC
        ) AS revenue_group

    FROM customer_metrics cm
)

SELECT
    rc.customer_id,

    rc.total_orders,

    ROUND(rc.realized_revenue, 2)
        AS realized_revenue,

    ROUND(rc.realized_profit, 2)
        AS realized_profit,

    ROUND(rc.realized_margin_pct, 2)
        AS realized_margin_pct,

    ROUND(rc.return_rate, 2)
        AS return_rate,

    ROUND(rc.average_discount_pct, 2)
        AS average_discount_pct

FROM ranked_customers rc

CROSS JOIN company_stats cs

WHERE
    rc.revenue_group = 1

    AND (
        rc.realized_margin_pct
            < cs.company_median_margin

        OR

        rc.return_rate
            > cs.company_average_return_rate
    )

ORDER BY
    rc.realized_revenue DESC

LIMIT 15;



-- Question 4: Revenue target achieved, but business target missed
-- Join actual performance with monthly_targets.
-- For every region and month calculate:
-- Revenue Target Attainment %

-- and:
-- Margin Gap
-- = Actual Realized Margin % - Target Margin %

-- Identify situations where:
-- Revenue Target Attainment >= 100%

-- but:
-- Actual Margin < Target Margin

-- These should be classified as:
-- Unprofitable Growth

DESCRIBE monthly_targets;

ALTER TABLE monthly_targets
CHANGE COLUMN `ï»¿region` region TEXT;

DESCRIBE analysis_ready;

SELECT
    a.region,
    a.month AS actual_month,
    t.month AS target_month,
    t.revenue_target,
    t.profit_margin_target_pct
FROM analysis_ready a
JOIN monthly_targets t
    ON a.region = t.region
    AND a.month = t.month
LIMIT 20;


WITH actual_performance AS (

    SELECT
        region,
        month,

        SUM(realized_revenue) AS actual_revenue,

        SUM(realized_profit) AS actual_profit,

        SUM(realized_profit)
        / NULLIF(SUM(realized_revenue), 0) * 100
        AS actual_margin_pct

    FROM analysis_ready

    GROUP BY
        region,
        month
)

SELECT
    a.region,
    a.month,

    ROUND(a.actual_revenue, 2)
        AS actual_revenue,

    ROUND(t.revenue_target, 2)
        AS revenue_target,

    ROUND(
        a.actual_revenue
        / NULLIF(t.revenue_target, 0) * 100,
        2
    ) AS revenue_target_attainment_pct,

    ROUND(a.actual_margin_pct, 2)
        AS actual_margin_pct,

    ROUND(t.profit_margin_target_pct, 2)
        AS target_margin_pct,

    ROUND(
        a.actual_margin_pct
        - t.profit_margin_target_pct,
        2
    ) AS margin_gap

FROM actual_performance a


JOIN monthly_targets t
    ON a.region = t.region
    AND a.month = t.month

ORDER BY
    a.region,
    a.month;
