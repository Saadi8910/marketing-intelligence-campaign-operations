-- =====================================================================
-- 02_create_raw_table.sql
-- Purpose : Land the CSV "as is" in a raw table.
--
-- Design decision: every raw column is VARCHAR.
--   * The raw layer must never reject or silently alter a source row.
--   * The Income column contains blanks; loading straight into DECIMAL
--     would convert blanks to 0 (or fail in strict mode), which would
--     hide a real data-quality issue. Typing happens in 04_clean.
--   * The source header " Income " contains leading/trailing spaces;
--     the raw column is named `income` and the mapping is documented.
--
-- Run from the REPOSITORY ROOT so the relative file path resolves:
--   mysql --local-infile=1 -u <user> -p marketing_intelligence < sql/02_create_raw_table.sql
-- The server must allow it:  SET GLOBAL local_infile = 1;
-- Alternative: MySQL Workbench > Table Data Import Wizard into this table.
-- =====================================================================

USE marketing_intelligence;

DROP TABLE IF EXISTS raw_marketing_campaign;

CREATE TABLE raw_marketing_campaign (
    raw_row_id            INT AUTO_INCREMENT PRIMARY KEY,  -- load order, for traceability
    id                    VARCHAR(20),
    year_birth            VARCHAR(10),
    education             VARCHAR(50),
    marital_status        VARCHAR(50),
    income                VARCHAR(30),   -- source header: " Income "
    kidhome               VARCHAR(10),
    teenhome              VARCHAR(10),
    dt_customer           VARCHAR(20),
    recency               VARCHAR(10),
    mnt_wines             VARCHAR(20),
    mnt_fruits            VARCHAR(20),
    mnt_meat_products     VARCHAR(20),
    mnt_fish_products     VARCHAR(20),
    mnt_sweet_products    VARCHAR(20),
    mnt_gold_prods        VARCHAR(20),
    num_deals_purchases   VARCHAR(10),
    num_web_purchases     VARCHAR(10),
    num_catalog_purchases VARCHAR(10),
    num_store_purchases   VARCHAR(10),
    num_web_visits_month  VARCHAR(10),
    accepted_cmp3         VARCHAR(5),
    accepted_cmp4         VARCHAR(5),
    accepted_cmp5         VARCHAR(5),
    accepted_cmp1         VARCHAR(5),
    accepted_cmp2         VARCHAR(5),
    response              VARCHAR(5),
    complain              VARCHAR(5),
    country               VARCHAR(50),
    loaded_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Column order below matches the CSV column order exactly.
-- File is UTF-8 with BOM and Windows (CRLF) line endings.
LOAD DATA LOCAL INFILE 'F:/Saad-git/New folder/marketing-intelligence-campaign-operations/data/raw/marketing_data.csv'
INTO TABLE raw_marketing_campaign
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES                       -- header row (also contains the BOM)
(id, year_birth, education, marital_status, income, kidhome, teenhome,
 dt_customer, recency, mnt_wines, mnt_fruits, mnt_meat_products,
 mnt_fish_products, mnt_sweet_products, mnt_gold_prods,
 num_deals_purchases, num_web_purchases, num_catalog_purchases,
 num_store_purchases, num_web_visits_month, accepted_cmp3, accepted_cmp4,
 accepted_cmp5, accepted_cmp1, accepted_cmp2, response, complain, country);

-- Load reconciliation: the source file has 2,241 lines = 1 header + 2,240 rows.
SELECT COUNT(*)                                   AS rows_loaded,
       2240                                       AS rows_expected,
       CASE WHEN COUNT(*) = 2240 THEN 'PASS' ELSE 'FAIL - investigate load' END AS load_check
FROM raw_marketing_campaign;
