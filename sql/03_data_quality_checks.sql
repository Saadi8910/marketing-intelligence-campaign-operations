-- =====================================================================
-- 03_data_quality_checks.sql
-- Purpose : Profile the RAW table BEFORE any cleaning, so every rule in
--           04_clean_marketing_data.sql is justified by evidence.
--           Results are documented in documentation/DATA_QUALITY.md.
-- Layer   : raw_marketing_campaign (all VARCHAR)
-- =====================================================================

USE marketing_intelligence;

-- ---------------------------------------------------------------------
-- DQ-01  Volume and key uniqueness
-- Why: a customer-level report double-counts if ID is not unique.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                         AS total_rows,
       COUNT(DISTINCT id)               AS distinct_ids,
       COUNT(*) - COUNT(DISTINCT id)    AS duplicate_ids
FROM raw_marketing_campaign;

-- ---------------------------------------------------------------------
-- DQ-02  Missing / blank values per column
-- Why: blanks in the raw layer are empty strings, not NULL, so both
--      are checked. Only columns with issues need follow-up.
-- ---------------------------------------------------------------------
SELECT
  SUM(NULLIF(TRIM(id),'')                   IS NULL) AS id_missing,
  SUM(NULLIF(TRIM(year_birth),'')           IS NULL) AS year_birth_missing,
  SUM(NULLIF(TRIM(education),'')            IS NULL) AS education_missing,
  SUM(NULLIF(TRIM(marital_status),'')       IS NULL) AS marital_status_missing,
  SUM(NULLIF(TRIM(income),'')               IS NULL) AS income_missing,
  SUM(NULLIF(TRIM(dt_customer),'')          IS NULL) AS dt_customer_missing,
  SUM(NULLIF(TRIM(recency),'')              IS NULL) AS recency_missing,
  SUM(NULLIF(TRIM(mnt_wines),'')            IS NULL) AS mnt_wines_missing,
  SUM(NULLIF(TRIM(num_web_purchases),'')    IS NULL) AS num_web_purchases_missing,
  SUM(NULLIF(TRIM(num_store_purchases),'')  IS NULL) AS num_store_purchases_missing,
  SUM(NULLIF(TRIM(accepted_cmp1),'')        IS NULL) +
  SUM(NULLIF(TRIM(accepted_cmp2),'')        IS NULL) +
  SUM(NULLIF(TRIM(accepted_cmp3),'')        IS NULL) +
  SUM(NULLIF(TRIM(accepted_cmp4),'')        IS NULL) +
  SUM(NULLIF(TRIM(accepted_cmp5),'')        IS NULL) +
  SUM(NULLIF(TRIM(response),'')             IS NULL) AS campaign_fields_missing,
  SUM(NULLIF(TRIM(country),'')              IS NULL) AS country_missing
FROM raw_marketing_campaign;

-- ---------------------------------------------------------------------
-- DQ-03  Non-numeric content in numeric columns
-- Why: confirms the columns can be safely cast in the staging layer.
-- ---------------------------------------------------------------------
SELECT 'year_birth' AS column_name, COUNT(*) AS non_numeric_rows
FROM raw_marketing_campaign WHERE year_birth NOT REGEXP '^[0-9]+$'
UNION ALL
SELECT 'income', COUNT(*) FROM raw_marketing_campaign
WHERE TRIM(income) <> '' AND TRIM(income) NOT REGEXP '^[0-9]+(\\.[0-9]+)?$'
UNION ALL
SELECT 'recency', COUNT(*) FROM raw_marketing_campaign WHERE recency NOT REGEXP '^[0-9]+$'
UNION ALL
SELECT 'mnt_* (any)', COUNT(*) FROM raw_marketing_campaign
WHERE CONCAT_WS('|', mnt_wines, mnt_fruits, mnt_meat_products, mnt_fish_products,
                mnt_sweet_products, mnt_gold_prods)
      NOT REGEXP '^[0-9]+(\\|[0-9]+){5}$'
UNION ALL
SELECT 'num_* (any)', COUNT(*) FROM raw_marketing_campaign
WHERE CONCAT_WS('|', num_deals_purchases, num_web_purchases, num_catalog_purchases,
                num_store_purchases, num_web_visits_month)
      NOT REGEXP '^[0-9]+(\\|[0-9]+){4}$';

-- ---------------------------------------------------------------------
-- DQ-04  Campaign / complaint flags must be strictly 0 or 1
-- Why: acceptance rate = AVG(flag); any other value corrupts the KPI.
-- ---------------------------------------------------------------------
SELECT SUM(accepted_cmp1 NOT IN ('0','1')) AS bad_cmp1,
       SUM(accepted_cmp2 NOT IN ('0','1')) AS bad_cmp2,
       SUM(accepted_cmp3 NOT IN ('0','1')) AS bad_cmp3,
       SUM(accepted_cmp4 NOT IN ('0','1')) AS bad_cmp4,
       SUM(accepted_cmp5 NOT IN ('0','1')) AS bad_cmp5,
       SUM(response      NOT IN ('0','1')) AS bad_response,
       SUM(complain      NOT IN ('0','1')) AS bad_complain
FROM raw_marketing_campaign;

-- ---------------------------------------------------------------------
-- DQ-05  Date validity and range of Dt_Customer (enrollment date)
-- Why: the only date in the dataset; it drives the Date dimension.
-- ---------------------------------------------------------------------
SELECT SUM(STR_TO_DATE(dt_customer, '%Y-%m-%d') IS NULL) AS unparseable_dates,
       MIN(STR_TO_DATE(dt_customer, '%Y-%m-%d'))         AS first_enrollment,
       MAX(STR_TO_DATE(dt_customer, '%Y-%m-%d'))         AS last_enrollment
FROM raw_marketing_campaign;

-- ---------------------------------------------------------------------
-- DQ-06  Birth year plausibility
-- Why: age segments are a core dashboard slicer. The data has no
--      extraction date; the last enrollment is 2014-06-29, so 2014 is
--      used as the reference year (documented assumption).
-- ---------------------------------------------------------------------
SELECT MIN(CAST(year_birth AS UNSIGNED)) AS min_birth_year,
       MAX(CAST(year_birth AS UNSIGNED)) AS max_birth_year,
       SUM(CAST(year_birth AS UNSIGNED) < 1920) AS birth_year_before_1920
FROM raw_marketing_campaign;

-- Show the implausible rows and the gap to the next earliest birth year.
SELECT id, year_birth, 2014 - CAST(year_birth AS UNSIGNED) AS implied_age_2014, country
FROM raw_marketing_campaign
ORDER BY CAST(year_birth AS UNSIGNED)
LIMIT 5;

-- ---------------------------------------------------------------------
-- DQ-07  Income outliers (window function: rank + gap to next value)
-- Why: a single extreme value distorts average income per segment.
-- ---------------------------------------------------------------------
WITH income_ranked AS (
    SELECT id,
           CAST(income AS DECIMAL(12,2)) AS income,
           ROW_NUMBER() OVER (ORDER BY CAST(income AS DECIMAL(12,2)) DESC) AS income_rank,
           LEAD(CAST(income AS DECIMAL(12,2)))
               OVER (ORDER BY CAST(income AS DECIMAL(12,2)) DESC) AS next_lower_income
    FROM raw_marketing_campaign
    WHERE TRIM(income) <> ''
)
SELECT id, income, next_lower_income,
       ROUND(income / next_lower_income, 2) AS ratio_to_next
FROM income_ranked
WHERE income_rank <= 5;

-- ---------------------------------------------------------------------
-- DQ-08  Categorical domains
-- Why: unexpected labels fragment slicers and segment totals.
-- ---------------------------------------------------------------------
SELECT 'education' AS field, education AS value, COUNT(*) AS n
FROM raw_marketing_campaign GROUP BY education
UNION ALL
SELECT 'marital_status', marital_status, COUNT(*)
FROM raw_marketing_campaign GROUP BY marital_status
UNION ALL
SELECT 'country', country, COUNT(*)
FROM raw_marketing_campaign GROUP BY country
ORDER BY field, n DESC;

-- ---------------------------------------------------------------------
-- DQ-09  Suspected duplicate customers
-- Finding: IDs are unique, but many rows are identical on EVERY field
-- except ID and Country (same birth year, income, enrollment date,
-- all six product amounts, all channel counts and all campaign flags).
-- Two genuine customers matching on ~25 fields is not plausible, so
-- these are treated as suspected duplicate records.
-- ---------------------------------------------------------------------
WITH profile_groups AS (
    SELECT year_birth, education, marital_status, income, kidhome, teenhome,
           dt_customer, recency, mnt_wines, mnt_fruits, mnt_meat_products,
           mnt_fish_products, mnt_sweet_products, mnt_gold_prods,
           num_deals_purchases, num_web_purchases, num_catalog_purchases,
           num_store_purchases, num_web_visits_month, accepted_cmp1, accepted_cmp2,
           accepted_cmp3, accepted_cmp4, accepted_cmp5, response, complain,
           COUNT(*)                AS rows_in_group,
           COUNT(DISTINCT country) AS countries_in_group
    FROM raw_marketing_campaign
    GROUP BY year_birth, education, marital_status, income, kidhome, teenhome,
             dt_customer, recency, mnt_wines, mnt_fruits, mnt_meat_products,
             mnt_fish_products, mnt_sweet_products, mnt_gold_prods,
             num_deals_purchases, num_web_purchases, num_catalog_purchases,
             num_store_purchases, num_web_visits_month, accepted_cmp1, accepted_cmp2,
             accepted_cmp3, accepted_cmp4, accepted_cmp5, response, complain
)
SELECT COUNT(*)                                        AS distinct_profiles,
       SUM(rows_in_group > 1)                          AS duplicate_groups,
       SUM(CASE WHEN rows_in_group > 1 THEN rows_in_group - 1 ELSE 0 END) AS surplus_rows,
       SUM(rows_in_group > 1 AND countries_in_group > 1) AS groups_with_country_conflict
FROM profile_groups;

-- Same check, but ALSO matching on Country (strict duplicates).
SELECT COUNT(*) - COUNT(DISTINCT CONCAT_WS('|', year_birth, education, marital_status,
       income, kidhome, teenhome, dt_customer, recency, mnt_wines, mnt_fruits,
       mnt_meat_products, mnt_fish_products, mnt_sweet_products, mnt_gold_prods,
       num_deals_purchases, num_web_purchases, num_catalog_purchases,
       num_store_purchases, num_web_visits_month, accepted_cmp1, accepted_cmp2,
       accepted_cmp3, accepted_cmp4, accepted_cmp5, response, complain, country))
       AS surplus_rows_incl_country
FROM raw_marketing_campaign;

-- ---------------------------------------------------------------------
-- DQ-10  Logical consistency between related fields
-- Why: these fields describe the same customer behaviour and should
--      agree; disagreements make cross-metric KPIs misleading.
-- ---------------------------------------------------------------------
WITH typed AS (
    SELECT id,
           CAST(mnt_wines AS UNSIGNED) + CAST(mnt_fruits AS UNSIGNED)
         + CAST(mnt_meat_products AS UNSIGNED) + CAST(mnt_fish_products AS UNSIGNED)
         + CAST(mnt_sweet_products AS UNSIGNED) + CAST(mnt_gold_prods AS UNSIGNED) AS total_spend,
           CAST(num_web_purchases AS UNSIGNED) + CAST(num_catalog_purchases AS UNSIGNED)
         + CAST(num_store_purchases AS UNSIGNED)                                      AS channel_purchases,
           CAST(num_deals_purchases AS UNSIGNED)  AS deal_purchases,
           CAST(num_web_visits_month AS UNSIGNED) AS web_visits
    FROM raw_marketing_campaign
)
SELECT SUM(channel_purchases = 0 AND total_spend > 0)  AS spend_but_zero_purchases,
       SUM(deal_purchases > channel_purchases)         AS deals_exceed_total_purchases,
       SUM(web_visits > 10)                            AS web_visits_above_10,
       SUM(total_spend = 0)                            AS zero_spend_customers
FROM typed;

-- ---------------------------------------------------------------------
-- DQ-11  Small-sample segments
-- Why: a rate computed on 3 customers looks dramatic but is not
--      evidence. Segments under 30 rows are flagged in the dashboard.
-- ---------------------------------------------------------------------
SELECT country, COUNT(*) AS customers,
       CASE WHEN COUNT(*) < 30 THEN 'SMALL SAMPLE - interpret with caution' ELSE 'OK' END AS sample_flag
FROM raw_marketing_campaign
GROUP BY country
ORDER BY customers;
