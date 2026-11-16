
-- =====================================================
-- PROJECT: METALTRACK - JEWELLERY RETAIL ANALYTICS
-- DATABASE: PostgreSQL - metaltrack_db
-- FILE: MetalTrack_15_Business_Queries.sql
-- =====================================================
--
-- PURPOSE:
-- Business analysis using SQL queries for:
-- 1. Metal rate analysis
-- 2. Inventory management
-- 3. Stock movements and transfers
-- 4. Purchase and supplier analysis
-- 5. Wholesale sales and customer analysis
-- 6. Pricing and making charges
--
-- =====================================================
-- BUSINESS QUERIES
-- =====================================================


-- =====================================================
-- QUERY 1: BRANCH-WISE INVENTORY SUMMARY
-- =====================================================
-- Business Question:
-- What is the opening inventory of each branch?
-- How much stock entered and left each branch?
-- Which branches have the highest closing stock?
--
-- Note:
-- Closing stock is calculated from inventory movements.
-- =====================================================

SELECT
    branch_name,

    ROUND(opening_weight, 2)
        AS opening_weight,

    ROUND(total_inflow, 2)
        AS total_inflow,

    ROUND(total_outflow, 2)
        AS total_outflow,

    ROUND(calculated_closing_weight, 2)
        AS closing_stock_weight

FROM public.vw_branch_inventory_summary

ORDER BY calculated_closing_weight DESC;

-- =====================================================
-- END OF QUERY 1
-- =====================================================




-- =====================================================
-- QUERY 2: BRANCH-WISE STOCK MOVEMENT ANALYSIS
-- =====================================================
-- Business Question:
-- Which branches have the highest stock inflows?
-- Which branches have net stock outflows?
-- What is the net movement of inventory by branch?
--
-- Note:
-- Net movement equals inflows minus outflows.
-- It does not represent the final closing stock.
-- =====================================================

SELECT
    branch_name,

    ROUND(total_inflow, 2)
        AS total_stock_inflow,

    ROUND(total_outflow, 2)
        AS total_stock_outflow,

    ROUND(
        total_inflow - total_outflow,
        2
    ) AS net_stock_movement,

    CASE
        WHEN total_inflow > total_outflow
            THEN 'NET INFLOW'

        WHEN total_inflow < total_outflow
            THEN 'NET OUTFLOW'

        ELSE 'BALANCED'
    END AS movement_status

FROM public.vw_branch_inventory_summary

ORDER BY total_inflow DESC;

-- =====================================================
-- END OF QUERY 2
-- =====================================================


-- =====================================================
-- QUERY 3: BRANCH-WISE INVENTORY RECONCILIATION
-- =====================================================
-- Business Question:
-- Are inventory balances reconciled by branch and metal?
-- Which branches have the highest stock differences?
-- What is the reconciliation status of each record?
--
-- Note:
-- Reconciliation differences are system-calculated.
-- Physical stock verification requires a stock count.
-- =====================================================

SELECT
    branch_name,

    metal,

    ROUND(opening_weight, 2)
        AS opening_stock,

    ROUND(total_inflow, 2)
        AS total_inflow,

    ROUND(total_outflow, 2)
        AS total_outflow,

    ROUND(closing_weight, 2)
        AS closing_stock,

    ROUND(reconciliation_difference, 2)
        AS stock_difference,

    reconciliation_status

FROM public.vw_inventory_reconciliation

ORDER BY
    ABS(reconciliation_difference) DESC NULLS LAST,
    branch_name,
    metal;

-- =====================================================
-- END OF QUERY 3
-- =====================================================


-- =====================================================
-- QUERY 4: BRANCH-TO-BRANCH STOCK TRANSFER ANALYSIS
-- =====================================================
-- Business Question:
-- Which branches send inventory to other branches?
-- What is the total transferred weight and value?
-- Which branch-to-branch routes have the highest
-- inventory movement?
--
-- Note:
-- Return transfers and records with missing
-- sending or receiving branches are excluded.
-- =====================================================

SELECT
    from_branch_id AS sending_branch,

    to_branch_id AS receiving_branch,

    COUNT(DISTINCT transfer_id)
        AS total_transfers,

    ROUND(
        SUM(net_weight)::numeric,
        2
    ) AS total_transfer_weight,

    ROUND(
        SUM(total_value)::numeric,
        2
    ) AS total_transfer_value

FROM public.vw_stock_transfer_clean

WHERE from_branch_id IS NOT NULL
  AND to_branch_id IS NOT NULL
  AND is_return IS NOT TRUE

GROUP BY
    from_branch_id,
    to_branch_id

ORDER BY
    total_transfer_weight DESC NULLS LAST;

-- =====================================================
-- END OF QUERY 4
-- =====================================================



-- =====================================================
-- QUERY 5: BRANCH-WISE STOCK ADJUSTMENT ANALYSIS
-- =====================================================
-- Business Question:
-- Which branches have the highest stock adjustments?
-- What is the total adjusted weight and value?
-- How do adjustments differ by adjustment action?
--
-- Note:
-- Absolute values measure gross adjustment activity,
-- not confirmed stock loss or shrinkage.
-- =====================================================

SELECT
    branch_id,

    adjustment_action,

    COUNT(DISTINCT adjustment_id)
        AS total_adjustments,

    COUNT(*)
        AS adjustment_lines,

    ROUND(
        SUM(ABS(COALESCE(net_weight, 0)))::numeric,
        2
    ) AS total_adjusted_weight,

    ROUND(
        SUM(ABS(COALESCE(metal_value, 0)))::numeric,
        2
    ) AS total_adjusted_metal_value,

    ROUND(
        SUM(ABS(COALESCE(total_amount, 0)))::numeric,
        2
    ) AS total_adjusted_amount

FROM public.vw_metal_stock_adjustment_clean

GROUP BY
    branch_id,
    adjustment_action

ORDER BY
    total_adjusted_weight DESC;

-- =====================================================
-- END OF QUERY 5
-- =====================================================


-- =====================================================
-- QUERY 6: BRANCH-WISE PURCHASE PERFORMANCE
-- =====================================================
-- Business Question:
-- Which branches have the highest purchase values?
-- How many purchase orders and suppliers does each
-- branch have?
-- What percentage of total purchasing does each
-- branch contribute?
-- =====================================================

SELECT
    branch_name,

    total_purchase_orders,

    purchase_lines,

    total_suppliers,

    ROUND(total_purchased_weight, 2)
        AS purchased_weight,

    ROUND(total_purchase_value, 2)
        AS purchase_value,

    ROUND(
        100.0 * total_purchase_value /
        NULLIF(
            SUM(total_purchase_value) OVER (), 0
        ), 2
    ) AS purchase_share_percentage

FROM public.vw_purchase_branch_analysis

ORDER BY
    total_purchase_value DESC NULLS LAST;

-- =====================================================
-- END OF QUERY 6
-- =====================================================



-- =====================================================
-- QUERY 7: TOP 10 SUPPLIERS BY PURCHASE VALUE
-- =====================================================
-- Business Question:
-- Which suppliers have the highest purchase value?
-- What is each supplier's share of total purchases?
--
-- Note:
-- Purchase share is calculated in the source view.
-- =====================================================

SELECT
    supplier_id,
    supplier_name,

    total_purchases,
    purchase_lines,

    ROUND(total_purchased_weight, 2)
        AS purchased_weight,

    ROUND(total_purchase_value, 2)
        AS purchase_value,

    ROUND(purchase_share_percentage, 2)
        AS purchase_share_pct

FROM public.vw_purchase_supplier_analysis

ORDER BY
    total_purchase_value DESC NULLS LAST

LIMIT 10;

-- =====================================================
-- END OF QUERY 7
-- =====================================================


-- =====================================================
-- QUERY 8: MONTHLY PURCHASE TREND ANALYSIS
-- =====================================================
-- Business Question:
-- What is the monthly purchase value?
-- How much has purchasing increased or decreased
-- compared with the previous recorded month?
-- =====================================================

WITH monthly_purchases AS (
    SELECT
        purchase_month,
        total_purchase_orders,
        purchase_lines,
        total_purchased_weight,
        total_purchase_value,

        LAG(total_purchase_value) OVER (
            ORDER BY purchase_month
        ) AS previous_month_purchase_value

    FROM public.vw_monthly_purchase_trend
)

SELECT
    purchase_month,
    total_purchase_orders,
    purchase_lines,

    ROUND(
        total_purchased_weight,
        2
    ) AS total_purchased_weight,

    ROUND(
        total_purchase_value,
        2
    ) AS total_purchase_value,

    ROUND(
        previous_month_purchase_value,
        2
    ) AS previous_month_purchase_value,

    ROUND(
        100.0 *
        (
            total_purchase_value
            - previous_month_purchase_value
        )
        / NULLIF(previous_month_purchase_value, 0),
        2
    ) AS monthly_growth_percentage

FROM monthly_purchases

ORDER BY purchase_month DESC;

-- =====================================================
-- END OF QUERY 8
-- =====================================================



-- =====================================================
-- QUERY 9: WHOLESALE METAL VS DIAMOND SALES
-- =====================================================
-- Business Question:
-- How do metal and diamond wholesale sales compare?
-- What percentage of wholesale sales comes from each?
--
-- Note:
-- Return lines are excluded from this analysis.
-- =====================================================

WITH wholesale_summary AS (
    SELECT
        sales_type,

        COUNT(DISTINCT (branch_id, sale_id))
            AS total_invoices,

        COUNT(*) AS sales_lines,

        COUNT(DISTINCT customer_id)
            AS total_customers,

        ROUND(
            SUM(COALESCE(sales_value, 0))::numeric,
            2
        ) AS total_sales_value,

        ROUND(
            SUM(COALESCE(sales_weight, 0))::numeric,
            2
        ) AS total_sales_weight

    FROM public.vw_wholesale_sales_analysis

    WHERE line_is_return IS NOT TRUE

    GROUP BY sales_type
)

SELECT
    sales_type,
    total_invoices,
    sales_lines,
    total_customers,
    total_sales_value,
    total_sales_weight,

    ROUND(
        100.0 * total_sales_value
        / NULLIF(
            SUM(total_sales_value) OVER (),
            0
        ),
        2
    ) AS sales_share_percentage

FROM wholesale_summary

ORDER BY total_sales_value DESC;

-- =====================================================
-- END OF QUERY 9
-- =====================================================



-- =====================================================
-- QUERY 10: TOP 10 WHOLESALE CUSTOMERS
-- =====================================================
-- Business Question:
-- Which customers generate the highest wholesale sales?
-- What percentage of total wholesale sales does
-- each customer contribute?
--
-- Note:
-- Return lines are excluded from this analysis.
-- =====================================================

WITH customer_sales AS (
    SELECT
        customer_id,

        COUNT(*) AS sales_lines,

        ROUND(
            SUM(COALESCE(sales_value, 0))::numeric,
            2
        ) AS total_customer_sales

    FROM public.vw_wholesale_sales_analysis

    WHERE line_is_return IS NOT TRUE
      AND customer_id IS NOT NULL

    GROUP BY customer_id
)

SELECT
    customer_id,
    sales_lines,
    total_customer_sales,

    ROUND(
        100.0 * total_customer_sales
        / NULLIF(
            SUM(total_customer_sales) OVER (),
            0
        ),
        2
    ) AS customer_sales_share_pct

FROM customer_sales

ORDER BY total_customer_sales DESC

LIMIT 10;

-- =====================================================
-- END OF QUERY 10
-- =====================================================


-- =====================================================
-- QUERY 11: MAKING CHARGE ANALYSIS BY KARAT
-- =====================================================
-- Business Question:
-- Which metal types and karats generate the highest
-- making-charge value?
-- What percentage of net sales is making-charge value?
-- =====================================================

SELECT
    metal_type,
    karat_code,
    karat_name,

    COUNT(*) AS sales_lines,

    ROUND(
        SUM(COALESCE(net_amount, 0))::numeric,
        2
    ) AS total_net_sales,

    ROUND(
        SUM(COALESCE(making_value, 0))::numeric,
        2
    ) AS total_making_value,

    ROUND(
        AVG(making_charge)::numeric,
        2
    ) AS average_making_charge,

    ROUND(
        (
            100.0 * SUM(COALESCE(making_value, 0))
            / NULLIF(SUM(COALESCE(net_amount, 0)), 0)
        )::numeric,
        2
    ) AS making_value_percentage

FROM public.vw_pricing_making_charge_analysis

GROUP BY
    metal_type,
    karat_code,
    karat_name

ORDER BY total_making_value DESC;

-- =====================================================
-- END OF QUERY 11
-- =====================================================



-- =====================================================
-- QUERY 12: INVENTORY RECONCILIATION
-- =====================================================
-- Business Question:
-- Are inventory balances reconciled across branches?
-- What is the total reported stock difference?
--
-- Note:
-- A matched system balance does not independently
-- confirm physical stock accuracy.
-- =====================================================

SELECT
    reconciliation_status,

    COUNT(*) AS branch_metal_records,

    COUNT(DISTINCT branch_code)
        AS total_branches,

    ROUND(
        SUM(COALESCE(opening_weight, 0)),
        2
    ) AS total_opening_weight,

    ROUND(
        SUM(COALESCE(total_inflow, 0)),
        2
    ) AS total_inflow,

    ROUND(
        SUM(COALESCE(total_outflow, 0)),
        2
    ) AS total_outflow,

    ROUND(
        SUM(COALESCE(closing_weight, 0)),
        2
    ) AS total_closing_weight,

    ROUND(
        SUM(
            ABS(COALESCE(reconciliation_difference, 0))
        ),
        2
    ) AS total_absolute_difference

FROM public.vw_inventory_reconciliation

GROUP BY reconciliation_status

ORDER BY reconciliation_status;

-- =====================================================
-- END OF QUERY 12
-- =====================================================



-- =====================================================
-- QUERY 13: STOCK ADJUSTMENT ANALYSIS
-- =====================================================
-- Business Question:
-- Which branches have the highest stock adjustments?
-- What is the net impact of stock increases and decreases?
--
-- Note:
-- Stock decreases do not automatically indicate
-- shrinkage, theft, or wastage.
-- =====================================================

SELECT
    branch_id,

    COUNT(DISTINCT adjustment_id)
        AS total_adjustment_documents,

    COUNT(*)
        AS total_adjustment_lines,

    COUNT(*) FILTER (
        WHERE UPPER(TRIM(adjustment_action)) = 'INCREASE'
    ) AS increase_lines,

    COUNT(*) FILTER (
        WHERE UPPER(TRIM(adjustment_action)) = 'DECREASE'
    ) AS decrease_lines,

    ROUND(
        SUM(
            CASE
                WHEN UPPER(TRIM(adjustment_action)) = 'INCREASE'
                THEN ABS(COALESCE(pure_weight, 0))
                ELSE 0
            END
        )::numeric,
        2
    ) AS increased_weight,

    ROUND(
        SUM(
            CASE
                WHEN UPPER(TRIM(adjustment_action)) = 'DECREASE'
                THEN ABS(COALESCE(pure_weight, 0))
                ELSE 0
            END
        )::numeric,
        2
    ) AS decreased_weight,

    ROUND(
        SUM(
            CASE
                WHEN UPPER(TRIM(adjustment_action)) = 'INCREASE'
                THEN ABS(COALESCE(pure_weight, 0))
                WHEN UPPER(TRIM(adjustment_action)) = 'DECREASE'
                THEN -ABS(COALESCE(pure_weight, 0))
                ELSE 0
            END
        )::numeric,
        2
    ) AS net_adjustment_weight

FROM public.vw_metal_stock_adjustment_clean

GROUP BY branch_id

ORDER BY decreased_weight DESC;

-- =====================================================
-- END OF QUERY 13
-- =====================================================


-- =====================================================
-- QUERY 14: BRANCH STOCK TRANSFER ANALYSIS
-- =====================================================
-- Business Question:
-- Which branches transfer the most inventory?
-- Which branches receive the highest stock quantities?
-- =====================================================

WITH transfer_lines AS (
    SELECT
        from_branch_id,
        to_branch_id,
        transfer_id,
        COALESCE(net_weight, 0) AS net_weight,
        COALESCE(total_value, 0) AS total_value

    FROM public.vw_stock_transfer_clean

    WHERE is_return IS NOT TRUE
),

outgoing AS (
    SELECT
        from_branch_id AS branch_id,

        COUNT(DISTINCT transfer_id)
            AS outgoing_transfers,

        SUM(net_weight)
            AS outgoing_weight,

        SUM(total_value)
            AS outgoing_value

    FROM transfer_lines

    GROUP BY from_branch_id
),

incoming AS (
    SELECT
        to_branch_id AS branch_id,

        COUNT(DISTINCT transfer_id)
            AS incoming_transfers,

        SUM(net_weight)
            AS incoming_weight,

        SUM(total_value)
            AS incoming_value

    FROM transfer_lines

    GROUP BY to_branch_id
)

SELECT
    COALESCE(o.branch_id, i.branch_id)
        AS branch_id,

    COALESCE(o.outgoing_transfers, 0)
        AS outgoing_transfers,

    COALESCE(i.incoming_transfers, 0)
        AS incoming_transfers,

    ROUND(
        COALESCE(o.outgoing_weight, 0)::numeric,
        2
    ) AS outgoing_weight,

    ROUND(
        COALESCE(i.incoming_weight, 0)::numeric,
        2
    ) AS incoming_weight,

    ROUND(
        (
            COALESCE(i.incoming_weight, 0)
            - COALESCE(o.outgoing_weight, 0)
        )::numeric,
        2
    ) AS net_transfer_weight

FROM outgoing o

FULL OUTER JOIN incoming i
    ON o.branch_id = i.branch_id

ORDER BY outgoing_weight DESC;

-- =====================================================
-- END OF QUERY 14
-- =====================================================


-- =====================================================
-- QUERY 15: BRANCH INVENTORY PERFORMANCE
-- =====================================================
-- Business Question:
-- Which branches hold the highest closing inventory?
-- What percentage of total inventory does each hold?
-- =====================================================

WITH branch_inventory AS (
    SELECT
        branch_id,
        branch_name,

        ROUND(
            COALESCE(opening_weight, 0), 2
        ) AS opening_stock,

        ROUND(
            COALESCE(total_inflow, 0), 2
        ) AS stock_inflow,

        ROUND(
            COALESCE(total_outflow, 0), 2
        ) AS stock_outflow,

        ROUND(
            COALESCE(calculated_closing_weight, 0), 2
        ) AS closing_stock

    FROM public.vw_branch_inventory_summary
)

SELECT
    branch_id,
    branch_name,
    opening_stock,
    stock_inflow,
    stock_outflow,
    closing_stock,

    ROUND(
        100.0 * closing_stock /
        NULLIF(SUM(closing_stock) OVER (), 0),
        2
    ) AS stock_share_percentage

FROM branch_inventory

ORDER BY closing_stock DESC;

-- =====================================================
-- END OF QUERY 15
-- =====================================================
