-- =====================================================================
-- 06_kpi_queries.sql
-- Purpose :
--   Part 1  Headline KPIs = the "expected values" used to validate the
--           Power BI DAX measures (SQL and DAX must reconcile).
--   Part 2  Impact of the duplicate rule on KPIs (sensitivity check).
--   Part 3  KPI / data-quality monitoring objects used by n8n:
--           monitoring_thresholds, vw_monitoring_checks, monitoring_log.
-- =====================================================================

USE marketing_intelligence;

-- =====================================================================
-- PART 1  HEADLINE KPIs (reporting population)
-- =====================================================================
WITH cust AS (
    SELECT COUNT(*)                                  AS total_customers,
           SUM(total_spend)                          AS total_spend,
           AVG(total_spend)                          AS avg_customer_spend,
           AVG(income)                               AS avg_income,
           AVG(recency_days)                         AS avg_recency_days,
           AVG(recency_days <= 30)                   AS active_customer_rate,
           AVG(accepted_any_campaign)                AS campaign_engagement_rate,
           AVG(response_last_campaign)               AS last_campaign_rate,
           SUM(num_deals_purchases)                  AS deal_purchases,
           AVG(complain)                             AS complaint_rate
    FROM vw_dim_customer
),
camp AS (
    SELECT SUM(accepted) AS total_acceptances,
           AVG(accepted) AS overall_acceptance_rate      -- acceptances / (customers x 6)
    FROM vw_fact_campaign_response
),
chan AS (
    SELECT SUM(CASE WHEN channel_key = 1 THEN purchase_count END) AS web_purchases,
           SUM(CASE WHEN channel_key = 2 THEN purchase_count END) AS catalog_purchases,
           SUM(CASE WHEN channel_key = 3 THEN purchase_count END) AS store_purchases,
           SUM(purchase_count)                                    AS total_purchases
    FROM vw_fact_channel_purchases
)
SELECT 'Total Customers'               AS kpi, FORMAT(total_customers, 0)                AS value FROM cust
UNION ALL SELECT 'Total Spending',               FORMAT(total_spend, 0)                   FROM cust
UNION ALL SELECT 'Average Customer Spend',       FORMAT(avg_customer_spend, 2)            FROM cust
UNION ALL SELECT 'Average Income (known)',       FORMAT(avg_income, 0)                    FROM cust
UNION ALL SELECT 'Total Campaign Acceptances',   FORMAT(total_acceptances, 0)             FROM camp
UNION ALL SELECT 'Overall Acceptance Rate %',    FORMAT(100 * overall_acceptance_rate, 2) FROM camp
UNION ALL SELECT 'Last Campaign Response Rate %',FORMAT(100 * last_campaign_rate, 2)      FROM cust
UNION ALL SELECT 'Campaign Engagement Rate %',   FORMAT(100 * campaign_engagement_rate, 2) FROM cust
UNION ALL SELECT 'Total Web Purchases',          FORMAT(web_purchases, 0)                 FROM chan
UNION ALL SELECT 'Total Catalog Purchases',      FORMAT(catalog_purchases, 0)             FROM chan
UNION ALL SELECT 'Total Store Purchases',        FORMAT(store_purchases, 0)               FROM chan
UNION ALL SELECT 'Total Channel Purchases',      FORMAT(total_purchases, 0)               FROM chan
UNION ALL SELECT 'Total Deal Purchases',         FORMAT(deal_purchases, 0)                FROM cust
UNION ALL SELECT 'Store Share of Purchases %',   FORMAT(100 * store_purchases / total_purchases, 2) FROM chan
UNION ALL SELECT 'Average Recency (days)',       FORMAT(avg_recency_days, 2)              FROM cust
UNION ALL SELECT 'Active Customer Rate % (<=30d)', FORMAT(100 * active_customer_rate, 2)  FROM cust
UNION ALL SELECT 'Complaint Rate %',             FORMAT(100 * complaint_rate, 2)          FROM cust;

-- Product KPIs (validation targets for the product visuals)
SELECT p.product_name, SUM(f.spend_amount) AS total_spend,
       ROUND(100 * SUM(f.spend_amount) / SUM(SUM(f.spend_amount)) OVER (), 2) AS share_pct
FROM vw_fact_product_spend f JOIN dim_product p USING (product_key)
GROUP BY p.product_key, p.product_name ORDER BY total_spend DESC;

-- =====================================================================
-- PART 2  WHAT IF DUPLICATES WERE NOT REMOVED? (sensitivity)
-- Shows stakeholders exactly how much the cleaning rule moves each KPI.
-- =====================================================================
SELECT CASE include_in_reporting WHEN 1 THEN 'Deduplicated (reported)' END AS population,
       COUNT(*) AS customers, SUM(total_spend) AS total_spend,
       ROUND(AVG(total_spend), 2) AS avg_spend,
       ROUND(100 * AVG(response_last_campaign), 2) AS last_campaign_rate_pct
FROM stg_marketing_customers WHERE include_in_reporting = 1 GROUP BY include_in_reporting
UNION ALL
SELECT 'All raw rows (no dedup)', COUNT(*), SUM(total_spend),
       ROUND(AVG(total_spend), 2), ROUND(100 * AVG(response_last_campaign), 2)
FROM stg_marketing_customers;

-- =====================================================================
-- PART 3  MONITORING OBJECTS FOR n8n
-- =====================================================================

-- 3a. Thresholds live in a table, not in code, so a business owner can
--     change a limit without editing the workflow or the view.
DROP TABLE IF EXISTS monitoring_thresholds;
CREATE TABLE monitoring_thresholds (
    check_name      VARCHAR(60) PRIMARY KEY,
    check_category  VARCHAR(20)  NOT NULL,      -- 'Data quality' or 'KPI'
    comparison      VARCHAR(2)   NOT NULL,      -- '>' or '<' : ALERT when value <comparison> threshold
    threshold_value DECIMAL(12,4) NOT NULL,
    description     VARCHAR(255) NOT NULL
);

INSERT INTO monitoring_thresholds VALUES
('suspected_duplicate_rows',        'Data quality', '>', 0,    'Rows identical to another customer except ID/Country'),
('missing_income_pct',              'Data quality', '>', 2.0,  'Percent of rows with blank income'),
('invalid_birth_year_rows',         'Data quality', '>', 0,    'Rows with Year_Birth before 1920'),
('missing_campaign_flag_rows',      'Data quality', '>', 0,    'Rows with any blank campaign flag'),
('invalid_campaign_flag_rows',      'Data quality', '>', 0,    'Rows with a campaign flag other than 0/1'),
('raw_vs_staging_row_difference',   'Data quality', '>', 0,    'Raw rows minus staging rows (load completeness)'),
('last_campaign_response_rate_pct', 'KPI',          '<', 10.0, 'Last campaign response rate below target'),
('lowest_campaign_acceptance_pct',  'KPI',          '<', 2.0,  'Weakest campaign acceptance rate below floor'),
('catalog_purchase_share_pct',      'KPI',          '<', 15.0, 'Catalog share of channel purchases below floor');

-- 3b. One row per check with its current value and status.
--     Column names match monitoring_log so n8n can auto-map the insert.
CREATE OR REPLACE VIEW vw_monitoring_checks AS
WITH metrics AS (
    SELECT 'suspected_duplicate_rows' AS check_name,
           CAST(SUM(is_suspected_duplicate) AS DECIMAL(12,4)) AS metric_value
    FROM stg_marketing_customers
    UNION ALL
    SELECT 'missing_income_pct', 100 * AVG(NULLIF(TRIM(income), '') IS NULL)
    FROM raw_marketing_campaign
    UNION ALL
    SELECT 'invalid_birth_year_rows', SUM(dq_birth_year_invalid)
    FROM stg_marketing_customers
    UNION ALL
    SELECT 'missing_campaign_flag_rows',
           SUM(NULLIF(TRIM(accepted_cmp1),'') IS NULL OR NULLIF(TRIM(accepted_cmp2),'') IS NULL
            OR NULLIF(TRIM(accepted_cmp3),'') IS NULL OR NULLIF(TRIM(accepted_cmp4),'') IS NULL
            OR NULLIF(TRIM(accepted_cmp5),'') IS NULL OR NULLIF(TRIM(response),'') IS NULL)
    FROM raw_marketing_campaign
    UNION ALL
    SELECT 'invalid_campaign_flag_rows',
           SUM(accepted_cmp1 NOT IN ('0','1') OR accepted_cmp2 NOT IN ('0','1')
            OR accepted_cmp3 NOT IN ('0','1') OR accepted_cmp4 NOT IN ('0','1')
            OR accepted_cmp5 NOT IN ('0','1') OR response NOT IN ('0','1'))
    FROM raw_marketing_campaign
    UNION ALL
    SELECT 'raw_vs_staging_row_difference',
           (SELECT COUNT(*) FROM raw_marketing_campaign) - (SELECT COUNT(*) FROM stg_marketing_customers)
    UNION ALL
    SELECT 'last_campaign_response_rate_pct', 100 * AVG(response_last_campaign)
    FROM vw_dim_customer
    UNION ALL
    SELECT 'lowest_campaign_acceptance_pct', MIN(rate_pct)
    FROM (SELECT campaign_key, 100 * AVG(accepted) AS rate_pct
          FROM vw_fact_campaign_response GROUP BY campaign_key) per_campaign
    UNION ALL
    SELECT 'catalog_purchase_share_pct',
           100 * SUM(CASE WHEN channel_key = 2 THEN purchase_count END) / SUM(purchase_count)
    FROM vw_fact_channel_purchases
)
SELECT m.check_name,
       t.check_category,
       ROUND(m.metric_value, 2)  AS metric_value,
       t.comparison,
       t.threshold_value,
       CASE WHEN (t.comparison = '>' AND m.metric_value > t.threshold_value)
              OR (t.comparison = '<' AND m.metric_value < t.threshold_value)
            THEN 'ALERT' ELSE 'OK' END AS status,
       CONCAT(t.description, ': value ', ROUND(m.metric_value, 2),
              ' (alert if ', t.comparison, ' ', ROUND(t.threshold_value, 2), ')') AS message
FROM metrics m
JOIN monitoring_thresholds t ON t.check_name = m.check_name;

-- 3c. Audit log written by n8n on every run (history of checks).
CREATE TABLE IF NOT EXISTS monitoring_log (
    log_id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    check_name      VARCHAR(60)   NOT NULL,
    check_category  VARCHAR(20)   NOT NULL,
    metric_value    DECIMAL(12,2) NULL,
    comparison      VARCHAR(2)    NOT NULL,
    threshold_value DECIMAL(12,4) NOT NULL,
    status          VARCHAR(10)   NOT NULL,
    message         VARCHAR(400)  NULL,
    INDEX ix_monitoring_log_run (run_at),
    INDEX ix_monitoring_log_status (status)
);

-- Preview what n8n will receive:
SELECT * FROM vw_monitoring_checks ORDER BY status, check_category, check_name;

-- Recommended least-privilege account for n8n (run as admin; choose
-- your own password - never commit it to Git):
-- CREATE USER 'n8n_monitor'@'%' IDENTIFIED BY '<choose-a-password>';
-- GRANT SELECT ON marketing_intelligence.* TO 'n8n_monitor'@'%';
-- GRANT INSERT ON marketing_intelligence.monitoring_log TO 'n8n_monitor'@'%';
