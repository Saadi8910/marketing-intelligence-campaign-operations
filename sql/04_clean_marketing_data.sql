-- =====================================================================
-- 04_clean_marketing_data.sql
-- Purpose : raw  -> stg_marketing_customers (typed, standardised, flagged)
--           stg  -> analytical star-schema views consumed by Power BI
--           stg  -> data-quality exception views
--
-- Principles
--   * Nothing is deleted. Every source row survives into staging with
--     flags explaining how it is treated. Reporting views filter on
--     include_in_reporting = 1, so totals are reproducible and auditable.
--   * Raw values are kept next to cleaned values where a rule changes
--     them (income_raw vs income, marital_status_raw vs marital_status).
--   * Reference date = 2014-06-29 (latest enrollment date in the data).
--     The source has no extraction date, so age and tenure are
--     calculated relative to this date. Documented in DATA_QUALITY.md.
-- =====================================================================

USE marketing_intelligence;

-- ---------------------------------------------------------------------
-- 1. STAGING TABLE (explicit DDL: types, PK and comments are part of
--    the documentation, so CREATE TABLE ... AS SELECT is not used)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg_marketing_customers;

CREATE TABLE stg_marketing_customers (
    customer_id               INT          NOT NULL PRIMARY KEY,
    -- demographics
    year_birth                SMALLINT     NOT NULL,
    age                       SMALLINT     NULL COMMENT 'Age at 2014 reference year; NULL if birth year invalid',
    age_group                 VARCHAR(20)  NOT NULL,
    education                 VARCHAR(20)  NOT NULL,
    education_order           TINYINT      NOT NULL COMMENT 'Sort key for education slicer',
    marital_status_raw        VARCHAR(20)  NOT NULL,
    marital_status            VARCHAR(20)  NOT NULL COMMENT 'Standardised',
    relationship_status       VARCHAR(20)  NOT NULL COMMENT 'Partnered / Not partnered / Unknown',
    income_raw                DECIMAL(12,2) NULL,
    income                    DECIMAL(12,2) NULL COMMENT 'NULL when missing or flagged as placeholder outlier',
    income_band               VARCHAR(20)  NOT NULL,
    income_band_order         TINYINT      NOT NULL,
    kidhome                   TINYINT      NOT NULL,
    teenhome                  TINYINT      NOT NULL,
    children_at_home          TINYINT      NOT NULL,
    has_children              VARCHAR(3)   NOT NULL,
    country                   VARCHAR(50)  NOT NULL,
    -- relationship with the company
    enrollment_date           DATE         NOT NULL,
    tenure_days               SMALLINT     NOT NULL COMMENT 'Days from enrollment to 2014-06-29',
    recency_days              SMALLINT     NOT NULL,
    recency_band              VARCHAR(25)  NOT NULL,
    recency_band_order        TINYINT      NOT NULL,
    complain                  TINYINT      NOT NULL,
    -- product spend (source: last 2 years)
    mnt_wines                 INT NOT NULL,
    mnt_fruits                INT NOT NULL,
    mnt_meat_products         INT NOT NULL,
    mnt_fish_products         INT NOT NULL,
    mnt_sweet_products        INT NOT NULL,
    mnt_gold_prods            INT NOT NULL,
    total_spend               INT NOT NULL,
    -- channel purchases
    num_deals_purchases       SMALLINT NOT NULL,
    num_web_purchases         SMALLINT NOT NULL,
    num_catalog_purchases     SMALLINT NOT NULL,
    num_store_purchases       SMALLINT NOT NULL,
    num_web_visits_month      SMALLINT NOT NULL,
    total_purchases           SMALLINT NOT NULL COMMENT 'Web + Catalog + Store (deals overlap these channels)',
    avg_spend_per_purchase    DECIMAL(10,2) NULL,
    preferred_channel         VARCHAR(20) NOT NULL,
    -- campaigns
    accepted_cmp1             TINYINT NOT NULL,
    accepted_cmp2             TINYINT NOT NULL,
    accepted_cmp3             TINYINT NOT NULL,
    accepted_cmp4             TINYINT NOT NULL,
    accepted_cmp5             TINYINT NOT NULL,
    response_last_campaign    TINYINT NOT NULL COMMENT 'Source column Response = campaign 6 (last)',
    prior_campaigns_accepted  TINYINT NOT NULL COMMENT 'Campaigns 1-5',
    total_campaigns_accepted  TINYINT NOT NULL COMMENT 'Campaigns 1-6',
    accepted_any_campaign     TINYINT NOT NULL,
    prior_acceptor_segment    VARCHAR(30) NOT NULL,
    -- segmentation computed on the reporting population only
    spend_quartile            VARCHAR(20) NULL,
    spend_quartile_order      TINYINT     NULL,
    -- duplicate handling
    duplicate_of_customer_id  INT     NOT NULL COMMENT 'Lowest ID in the identical-profile group (self if unique)',
    duplicate_group_size      TINYINT NOT NULL,
    is_suspected_duplicate    TINYINT NOT NULL COMMENT '1 = surplus copy, excluded from reporting',
    dq_country_conflict       TINYINT NOT NULL COMMENT '1 = copies of this profile disagree on country',
    -- data-quality flags
    dq_income_missing         TINYINT NOT NULL,
    dq_income_outlier         TINYINT NOT NULL,
    dq_birth_year_invalid     TINYINT NOT NULL,
    dq_marital_invalid        TINYINT NOT NULL,
    dq_spend_no_purchases     TINYINT NOT NULL,
    dq_deals_exceed_purchases TINYINT NOT NULL,
    dq_web_visits_outlier     TINYINT NOT NULL,
    dq_issue_count            TINYINT NOT NULL,
    include_in_reporting      TINYINT NOT NULL,
    processed_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO stg_marketing_customers (
    customer_id, year_birth, age, age_group, education, education_order,
    marital_status_raw, marital_status, relationship_status,
    income_raw, income, income_band, income_band_order,
    kidhome, teenhome, children_at_home, has_children, country,
    enrollment_date, tenure_days, recency_days, recency_band, recency_band_order, complain,
    mnt_wines, mnt_fruits, mnt_meat_products, mnt_fish_products, mnt_sweet_products,
    mnt_gold_prods, total_spend,
    num_deals_purchases, num_web_purchases, num_catalog_purchases, num_store_purchases,
    num_web_visits_month, total_purchases, avg_spend_per_purchase, preferred_channel,
    accepted_cmp1, accepted_cmp2, accepted_cmp3, accepted_cmp4, accepted_cmp5,
    response_last_campaign, prior_campaigns_accepted, total_campaigns_accepted,
    accepted_any_campaign, prior_acceptor_segment,
    spend_quartile, spend_quartile_order,
    duplicate_of_customer_id, duplicate_group_size, is_suspected_duplicate, dq_country_conflict,
    dq_income_missing, dq_income_outlier, dq_birth_year_invalid, dq_marital_invalid,
    dq_spend_no_purchases, dq_deals_exceed_purchases, dq_web_visits_outlier,
    dq_issue_count, include_in_reporting
)
WITH
-- Step 1: cast every column to its real type (no business rules yet)
typed AS (
    SELECT
        CAST(id AS UNSIGNED)                           AS customer_id,
        CAST(year_birth AS UNSIGNED)                   AS year_birth,
        TRIM(education)                                AS education,
        TRIM(marital_status)                           AS marital_status_raw,
        CAST(NULLIF(TRIM(income), '') AS DECIMAL(12,2)) AS income_raw,
        CAST(kidhome AS UNSIGNED)                      AS kidhome,
        CAST(teenhome AS UNSIGNED)                     AS teenhome,
        STR_TO_DATE(dt_customer, '%Y-%m-%d')           AS enrollment_date,
        CAST(recency AS UNSIGNED)                      AS recency_days,
        CAST(mnt_wines AS UNSIGNED)                    AS mnt_wines,
        CAST(mnt_fruits AS UNSIGNED)                   AS mnt_fruits,
        CAST(mnt_meat_products AS UNSIGNED)            AS mnt_meat_products,
        CAST(mnt_fish_products AS UNSIGNED)            AS mnt_fish_products,
        CAST(mnt_sweet_products AS UNSIGNED)           AS mnt_sweet_products,
        CAST(mnt_gold_prods AS UNSIGNED)               AS mnt_gold_prods,
        CAST(num_deals_purchases AS UNSIGNED)          AS num_deals_purchases,
        CAST(num_web_purchases AS UNSIGNED)            AS num_web_purchases,
        CAST(num_catalog_purchases AS UNSIGNED)        AS num_catalog_purchases,
        CAST(num_store_purchases AS UNSIGNED)          AS num_store_purchases,
        CAST(num_web_visits_month AS UNSIGNED)         AS num_web_visits_month,
        CAST(accepted_cmp1 AS UNSIGNED)                AS accepted_cmp1,
        CAST(accepted_cmp2 AS UNSIGNED)                AS accepted_cmp2,
        CAST(accepted_cmp3 AS UNSIGNED)                AS accepted_cmp3,
        CAST(accepted_cmp4 AS UNSIGNED)                AS accepted_cmp4,
        CAST(accepted_cmp5 AS UNSIGNED)                AS accepted_cmp5,
        CAST(response AS UNSIGNED)                     AS response_last_campaign,
        CAST(complain AS UNSIGNED)                     AS complain,
        TRIM(country)                                  AS country
    FROM raw_marketing_campaign
),
-- Step 2: derived business fields and data-quality flags (row level)
derived AS (
    SELECT t.*,
        CASE WHEN year_birth < 1920 THEN 1 ELSE 0 END                      AS dq_birth_year_invalid,
        CASE WHEN income_raw IS NULL THEN 1 ELSE 0 END                     AS dq_income_missing,
        -- 666,666 is 4x the next-highest income and a repeated-digit value:
        -- treated as a placeholder, not a real income.
        CASE WHEN income_raw > 200000 THEN 1 ELSE 0 END                    AS dq_income_outlier,
        CASE WHEN marital_status_raw IN ('YOLO', 'Absurd') THEN 1 ELSE 0 END AS dq_marital_invalid,
        mnt_wines + mnt_fruits + mnt_meat_products + mnt_fish_products
          + mnt_sweet_products + mnt_gold_prods                            AS total_spend,
        num_web_purchases + num_catalog_purchases + num_store_purchases    AS total_purchases,
        accepted_cmp1 + accepted_cmp2 + accepted_cmp3 + accepted_cmp4
          + accepted_cmp5                                                  AS prior_campaigns_accepted
    FROM typed t
),
-- Step 3: duplicate detection with a named window over the full profile
--         (every field except customer_id and country)
dedup AS (
    SELECT d.*,
        MIN(customer_id) OVER profile                                      AS duplicate_of_customer_id,
        COUNT(*)         OVER profile                                      AS duplicate_group_size,
        ROW_NUMBER()     OVER (profile ORDER BY customer_id)               AS dup_rank,
        CASE WHEN MIN(country) OVER profile <> MAX(country) OVER profile
             THEN 1 ELSE 0 END                                             AS dq_country_conflict
    FROM derived d
    WINDOW profile AS (
        PARTITION BY year_birth, education, marital_status_raw, income_raw, kidhome,
                     teenhome, enrollment_date, recency_days, mnt_wines, mnt_fruits,
                     mnt_meat_products, mnt_fish_products, mnt_sweet_products,
                     mnt_gold_prods, num_deals_purchases, num_web_purchases,
                     num_catalog_purchases, num_store_purchases, num_web_visits_month,
                     accepted_cmp1, accepted_cmp2, accepted_cmp3, accepted_cmp4,
                     accepted_cmp5, response_last_campaign, complain)
)
SELECT
    customer_id,
    year_birth,
    CASE WHEN dq_birth_year_invalid = 1 THEN NULL ELSE 2014 - year_birth END AS age,
    CASE WHEN dq_birth_year_invalid = 1  THEN 'Unknown'
         WHEN 2014 - year_birth <= 34    THEN '18-34'
         WHEN 2014 - year_birth <= 44    THEN '35-44'
         WHEN 2014 - year_birth <= 54    THEN '45-54'
         WHEN 2014 - year_birth <= 64    THEN '55-64'
         ELSE '65+' END                                                     AS age_group,
    education,
    CASE education WHEN 'Basic' THEN 1 WHEN '2n Cycle' THEN 2 WHEN 'Graduation' THEN 3
                   WHEN 'Master' THEN 4 WHEN 'PhD' THEN 5 ELSE 9 END        AS education_order,
    marital_status_raw,
    CASE WHEN marital_status_raw = 'Alone'            THEN 'Single'
         WHEN marital_status_raw IN ('YOLO','Absurd') THEN 'Unknown'
         ELSE marital_status_raw END                                        AS marital_status,
    CASE WHEN marital_status_raw IN ('Married','Together')                    THEN 'Partnered'
         WHEN marital_status_raw IN ('Single','Divorced','Widow','Alone')     THEN 'Not partnered'
         ELSE 'Unknown' END                                                 AS relationship_status,
    income_raw,
    CASE WHEN dq_income_outlier = 1 THEN NULL ELSE income_raw END           AS income,
    CASE WHEN income_raw IS NULL OR dq_income_outlier = 1 THEN 'Unknown'
         WHEN income_raw <  30000 THEN '<30k'
         WHEN income_raw <  50000 THEN '30k-50k'
         WHEN income_raw <  70000 THEN '50k-70k'
         WHEN income_raw <  90000 THEN '70k-90k'
         ELSE '90k+' END                                                    AS income_band,
    CASE WHEN income_raw IS NULL OR dq_income_outlier = 1 THEN 9
         WHEN income_raw <  30000 THEN 1 WHEN income_raw < 50000 THEN 2
         WHEN income_raw <  70000 THEN 3 WHEN income_raw < 90000 THEN 4
         ELSE 5 END                                                         AS income_band_order,
    kidhome, teenhome,
    kidhome + teenhome                                                      AS children_at_home,
    CASE WHEN kidhome + teenhome > 0 THEN 'Yes' ELSE 'No' END               AS has_children,
    country,
    enrollment_date,
    DATEDIFF('2014-06-29', enrollment_date)                                 AS tenure_days,
    recency_days,
    CASE WHEN recency_days <= 30 THEN 'Active (0-30 days)'
         WHEN recency_days <= 60 THEN 'Cooling (31-60 days)'
         ELSE 'Lapsing (61-99 days)' END                                    AS recency_band,
    CASE WHEN recency_days <= 30 THEN 1 WHEN recency_days <= 60 THEN 2 ELSE 3 END AS recency_band_order,
    complain,
    mnt_wines, mnt_fruits, mnt_meat_products, mnt_fish_products, mnt_sweet_products,
    mnt_gold_prods, total_spend,
    num_deals_purchases, num_web_purchases, num_catalog_purchases, num_store_purchases,
    num_web_visits_month, total_purchases,
    ROUND(total_spend / NULLIF(total_purchases, 0), 2)                      AS avg_spend_per_purchase,
    CASE WHEN total_purchases = 0 THEN 'No purchases'
         WHEN num_store_purchases   > GREATEST(num_web_purchases, num_catalog_purchases) THEN 'Store'
         WHEN num_web_purchases     > GREATEST(num_store_purchases, num_catalog_purchases) THEN 'Web'
         WHEN num_catalog_purchases > GREATEST(num_store_purchases, num_web_purchases) THEN 'Catalog'
         ELSE 'Tie (multi-channel)' END                                     AS preferred_channel,
    accepted_cmp1, accepted_cmp2, accepted_cmp3, accepted_cmp4, accepted_cmp5,
    response_last_campaign,
    prior_campaigns_accepted,
    prior_campaigns_accepted + response_last_campaign                       AS total_campaigns_accepted,
    CASE WHEN prior_campaigns_accepted + response_last_campaign > 0 THEN 1 ELSE 0 END AS accepted_any_campaign,
    CASE WHEN prior_campaigns_accepted = 0 THEN '0 prior acceptances'
         WHEN prior_campaigns_accepted = 1 THEN '1 prior acceptance'
         ELSE '2+ prior acceptances' END                                    AS prior_acceptor_segment,
    -- Quartiles only for the reporting population (surplus duplicates get NULL)
    CASE WHEN dup_rank = 1 THEN
         ELT(NTILE(4) OVER (PARTITION BY dup_rank = 1 ORDER BY total_spend DESC, customer_id),
             'Top 25%', 'Upper-mid 25%', 'Lower-mid 25%', 'Bottom 25%') END AS spend_quartile,
    CASE WHEN dup_rank = 1 THEN
         NTILE(4) OVER (PARTITION BY dup_rank = 1 ORDER BY total_spend DESC, customer_id) END AS spend_quartile_order,
    duplicate_of_customer_id,
    duplicate_group_size,
    CASE WHEN dup_rank > 1 THEN 1 ELSE 0 END                                AS is_suspected_duplicate,
    dq_country_conflict,
    dq_income_missing, dq_income_outlier, dq_birth_year_invalid, dq_marital_invalid,
    CASE WHEN total_purchases = 0 AND total_spend > 0 THEN 1 ELSE 0 END     AS dq_spend_no_purchases,
    CASE WHEN num_deals_purchases > total_purchases THEN 1 ELSE 0 END       AS dq_deals_exceed_purchases,
    CASE WHEN num_web_visits_month > 10 THEN 1 ELSE 0 END                   AS dq_web_visits_outlier,
    (CASE WHEN dup_rank > 1 THEN 1 ELSE 0 END) + dq_country_conflict + dq_income_missing
      + dq_income_outlier + dq_birth_year_invalid + dq_marital_invalid
      + (CASE WHEN total_purchases = 0 AND total_spend > 0 THEN 1 ELSE 0 END)
      + (CASE WHEN num_deals_purchases > total_purchases THEN 1 ELSE 0 END)
      + (CASE WHEN num_web_visits_month > 10 THEN 1 ELSE 0 END)             AS dq_issue_count,
    CASE WHEN dup_rank = 1 THEN 1 ELSE 0 END                                AS include_in_reporting
FROM dedup;

-- Reconciliation: staging must hold every raw row.
SELECT (SELECT COUNT(*) FROM raw_marketing_campaign)                   AS raw_rows,
       COUNT(*)                                                        AS staging_rows,
       SUM(include_in_reporting)                                       AS reporting_rows,
       SUM(is_suspected_duplicate)                                     AS excluded_duplicates,
       CASE WHEN COUNT(*) = (SELECT COUNT(*) FROM raw_marketing_campaign)
             AND SUM(include_in_reporting) + SUM(is_suspected_duplicate) = COUNT(*)
            THEN 'PASS' ELSE 'FAIL' END                                AS reconciliation
FROM stg_marketing_customers;

-- ---------------------------------------------------------------------
-- 2. SMALL REFERENCE DIMENSIONS
--    The source is "wide" (one column per campaign / product / channel).
--    These tables turn those column names into rows so Power BI can
--    slice by campaign, product and channel with one measure each.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_campaign;
CREATE TABLE dim_campaign (
    campaign_key      TINYINT PRIMARY KEY,
    campaign_name     VARCHAR(30) NOT NULL,
    campaign_short    VARCHAR(10) NOT NULL,
    campaign_sequence TINYINT     NOT NULL,
    is_last_campaign  TINYINT     NOT NULL,
    source_column     VARCHAR(20) NOT NULL
);
INSERT INTO dim_campaign VALUES
 (1, 'Campaign 1',        'Cmp 1', 1, 0, 'AcceptedCmp1'),
 (2, 'Campaign 2',        'Cmp 2', 2, 0, 'AcceptedCmp2'),
 (3, 'Campaign 3',        'Cmp 3', 3, 0, 'AcceptedCmp3'),
 (4, 'Campaign 4',        'Cmp 4', 4, 0, 'AcceptedCmp4'),
 (5, 'Campaign 5',        'Cmp 5', 5, 0, 'AcceptedCmp5'),
 (6, 'Last Campaign (6)', 'Last',  6, 1, 'Response');

DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product (
    product_key   TINYINT PRIMARY KEY,
    product_name  VARCHAR(20) NOT NULL,
    source_column VARCHAR(25) NOT NULL
);
INSERT INTO dim_product VALUES
 (1, 'Wines',  'MntWines'),
 (2, 'Fruits', 'MntFruits'),
 (3, 'Meat',   'MntMeatProducts'),
 (4, 'Fish',   'MntFishProducts'),
 (5, 'Sweets', 'MntSweetProducts'),
 (6, 'Gold',   'MntGoldProds');

DROP TABLE IF EXISTS dim_channel;
CREATE TABLE dim_channel (
    channel_key   TINYINT PRIMARY KEY,
    channel_name  VARCHAR(20) NOT NULL,
    source_column VARCHAR(25) NOT NULL
);
-- Deals (NumDealsPurchases) is NOT a channel: a discounted purchase is
-- also made through web, catalog or store, so adding it would double
-- count. It is analysed separately as a customer-level attribute.
INSERT INTO dim_channel VALUES
 (1, 'Web',     'NumWebPurchases'),
 (2, 'Catalog', 'NumCatalogPurchases'),
 (3, 'Store',   'NumStorePurchases');

-- ---------------------------------------------------------------------
-- 3. ANALYTICAL VIEWS FOR POWER BI (reporting population only)
-- ---------------------------------------------------------------------

-- Customer dimension: attributes + customer-grain behaviour.
CREATE OR REPLACE VIEW vw_dim_customer AS
SELECT customer_id, year_birth, age, age_group, education, education_order,
       marital_status, relationship_status, income, income_band, income_band_order,
       kidhome, teenhome, children_at_home, has_children, country,
       dq_country_conflict, enrollment_date, tenure_days, recency_days,
       recency_band, recency_band_order, complain, total_spend, total_purchases,
       num_deals_purchases, num_web_visits_month, avg_spend_per_purchase,
       preferred_channel, prior_campaigns_accepted, total_campaigns_accepted,
       accepted_any_campaign, response_last_campaign, prior_acceptor_segment,
       spend_quartile, spend_quartile_order, dq_issue_count
FROM stg_marketing_customers
WHERE include_in_reporting = 1;

-- Campaign fact: one row per customer per campaign (unpivot).
CREATE OR REPLACE VIEW vw_fact_campaign_response AS
SELECT customer_id, 1 AS campaign_key, accepted_cmp1 AS accepted FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 2, accepted_cmp2          FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 3, accepted_cmp3          FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 4, accepted_cmp4          FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 5, accepted_cmp5          FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 6, response_last_campaign FROM stg_marketing_customers WHERE include_in_reporting = 1;

-- Product spend fact: one row per customer per product.
CREATE OR REPLACE VIEW vw_fact_product_spend AS
SELECT customer_id, 1 AS product_key, mnt_wines AS spend_amount FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 2, mnt_fruits         FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 3, mnt_meat_products  FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 4, mnt_fish_products  FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 5, mnt_sweet_products FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 6, mnt_gold_prods     FROM stg_marketing_customers WHERE include_in_reporting = 1;

-- Channel purchases fact: one row per customer per channel.
CREATE OR REPLACE VIEW vw_fact_channel_purchases AS
SELECT customer_id, 1 AS channel_key, num_web_purchases AS purchase_count FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 2, num_catalog_purchases FROM stg_marketing_customers WHERE include_in_reporting = 1
UNION ALL SELECT customer_id, 3, num_store_purchases   FROM stg_marketing_customers WHERE include_in_reporting = 1;

-- ---------------------------------------------------------------------
-- 4. DATA-QUALITY VIEWS (ALL rows, including excluded duplicates)
-- ---------------------------------------------------------------------

-- One row per customer per issue; feeds the "Data Quality / Attention"
-- section of report page 3 and the n8n monitoring checks.
CREATE OR REPLACE VIEW vw_dq_exceptions AS
SELECT customer_id, 'DQ_DUPLICATE' AS issue_code, 'Suspected duplicate profile (surplus copy)' AS issue_description,
       'High' AS severity, 'Excluded from reporting; lowest ID kept' AS handling,
       include_in_reporting, CONCAT('Duplicate of ID ', duplicate_of_customer_id) AS detail
FROM stg_marketing_customers WHERE is_suspected_duplicate = 1
UNION ALL
SELECT customer_id, 'DQ_COUNTRY_CONFLICT', 'Copies of this profile disagree on country',
       'Medium', 'Kept; country treated as unverified', include_in_reporting, CONCAT('Country = ', country)
FROM stg_marketing_customers WHERE dq_country_conflict = 1 AND include_in_reporting = 1
UNION ALL
SELECT customer_id, 'DQ_INCOME_MISSING', 'Income is blank in source',
       'Medium', 'Kept; income band = Unknown; excluded from income averages', include_in_reporting, NULL
FROM stg_marketing_customers WHERE dq_income_missing = 1
UNION ALL
SELECT customer_id, 'DQ_INCOME_OUTLIER', 'Income 666,666 is a likely placeholder',
       'Medium', 'Kept; income set to NULL; band = Unknown', include_in_reporting, CONCAT('Raw income = ', income_raw)
FROM stg_marketing_customers WHERE dq_income_outlier = 1
UNION ALL
SELECT customer_id, 'DQ_BIRTH_YEAR', 'Birth year before 1920 (implied age 114+)',
       'Medium', 'Kept; age set to NULL; age group = Unknown', include_in_reporting, CONCAT('Year_Birth = ', year_birth)
FROM stg_marketing_customers WHERE dq_birth_year_invalid = 1
UNION ALL
SELECT customer_id, 'DQ_MARITAL', 'Non-standard marital status (YOLO/Absurd)',
       'Low', 'Kept; mapped to Unknown', include_in_reporting, CONCAT('Raw = ', marital_status_raw)
FROM stg_marketing_customers WHERE dq_marital_invalid = 1
UNION ALL
SELECT customer_id, 'DQ_SPEND_NO_PURCHASES', 'Spend recorded but 0 web/catalog/store purchases',
       'Low', 'Kept; flagged; avg spend per purchase = NULL', include_in_reporting, CONCAT('Total spend = ', total_spend)
FROM stg_marketing_customers WHERE dq_spend_no_purchases = 1
UNION ALL
SELECT customer_id, 'DQ_DEALS_GT_PURCHASES', 'Deal purchases exceed total channel purchases',
       'Low', 'Kept; flagged', include_in_reporting,
       CONCAT('Deals = ', num_deals_purchases, ', purchases = ', total_purchases)
FROM stg_marketing_customers WHERE dq_deals_exceed_purchases = 1
UNION ALL
SELECT customer_id, 'DQ_WEB_VISITS_OUTLIER', 'More than 10 web visits last month',
       'Low', 'Kept; flagged (plausible but unusual)', include_in_reporting,
       CONCAT('Visits = ', num_web_visits_month)
FROM stg_marketing_customers WHERE dq_web_visits_outlier = 1;

-- Check-level summary (one row per rule) for KPI cards / n8n.
CREATE OR REPLACE VIEW vw_dq_summary AS
SELECT e.issue_code,
       MAX(e.issue_description)                       AS issue_description,
       MAX(e.severity)                                AS severity,
       MAX(e.handling)                                AS handling,
       COUNT(*)                                       AS affected_rows,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM stg_marketing_customers), 2) AS pct_of_source_rows
FROM vw_dq_exceptions e
GROUP BY e.issue_code;

SELECT * FROM vw_dq_summary ORDER BY affected_rows DESC;
