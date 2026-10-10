-- =====================================================================
-- 05_marketing_analysis.sql
-- Purpose : Answer the project's business questions (sections A-C).
--           Section D (data quality) is answered by 03 and the vw_dq_* views.
-- Population: reporting set only (vw_dim_customer / vw_fact_*),
--             i.e. 2,058 customers after removing 182 suspected duplicates.
-- Results are summarised in documentation/BUSINESS_RECOMMENDATIONS.md.
-- =====================================================================

USE marketing_intelligence;

-- =====================================================================
-- A. CAMPAIGN PERFORMANCE
-- =====================================================================

-- A1/A2/A4  Acceptance count and rate per campaign, ranked best to worst.
SELECT c.campaign_name,
       SUM(f.accepted)                              AS acceptances,
       COUNT(*)                                     AS customer_base,
       ROUND(100 * AVG(f.accepted), 2)              AS acceptance_rate_pct,
       RANK() OVER (ORDER BY AVG(f.accepted) DESC)  AS performance_rank
FROM vw_fact_campaign_response f
JOIN dim_campaign c ON c.campaign_key = f.campaign_key
GROUP BY c.campaign_key, c.campaign_name
ORDER BY performance_rank;
-- Note: the dataset does not say how many customers each campaign was
-- sent to; every customer has a 0/1 flag for every campaign, so the
-- denominator is the full customer base for all six campaigns.

-- A3  Customer characteristics vs acceptance.
--     Uses a CTE + UNION ALL so all segment types land in one result.
WITH seg AS (
    SELECT 'Income band' AS dimension, income_band AS segment, income_band_order AS sort_key,
           response_last_campaign, accepted_any_campaign FROM vw_dim_customer
    UNION ALL
    SELECT 'Education', education, education_order, response_last_campaign, accepted_any_campaign FROM vw_dim_customer
    UNION ALL
    SELECT 'Relationship', relationship_status, 0, response_last_campaign, accepted_any_campaign FROM vw_dim_customer
    UNION ALL
    SELECT 'Children at home', CAST(children_at_home AS CHAR), children_at_home, response_last_campaign, accepted_any_campaign FROM vw_dim_customer
    UNION ALL
    SELECT 'Age group', age_group, 0, response_last_campaign, accepted_any_campaign FROM vw_dim_customer
    UNION ALL
    SELECT 'Spend quartile', spend_quartile, spend_quartile_order, response_last_campaign, accepted_any_campaign FROM vw_dim_customer
    UNION ALL
    SELECT 'Recency band', recency_band, recency_band_order, response_last_campaign, accepted_any_campaign FROM vw_dim_customer
)
SELECT dimension, segment,
       COUNT(*)                                   AS customers,
       ROUND(100 * AVG(response_last_campaign),1) AS last_campaign_rate_pct,
       ROUND(100 * AVG(accepted_any_campaign),1)  AS accepted_any_rate_pct,
       CASE WHEN COUNT(*) < 30 THEN 'small sample' ELSE '' END AS caution
FROM seg
GROUP BY dimension, segment, sort_key
ORDER BY dimension, sort_key, segment;

-- A3b Income and children are related, so check them TOGETHER before
--     recommending either as a targeting rule (interaction check).
SELECT income_band, has_children,
       COUNT(*)                                    AS customers,
       ROUND(100 * AVG(response_last_campaign), 1) AS last_campaign_rate_pct,
       ROUND(AVG(total_spend), 0)                  AS avg_spend,
       CASE WHEN COUNT(*) < 30 THEN 'small sample' ELSE '' END AS caution
FROM vw_dim_customer
WHERE income_band <> 'Unknown'
GROUP BY income_band_order, income_band, has_children
ORDER BY income_band_order, has_children;

-- A3c Size and response of the combined segment suggested by A3b.
SELECT CASE WHEN income >= 70000 AND has_children = 'No' THEN '70k+ income, no children'
            ELSE 'All other customers' END        AS segment,
       COUNT(*)                                    AS customers,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers,
       SUM(response_last_campaign)                 AS accepted_last,
       ROUND(100 * SUM(response_last_campaign) / SUM(SUM(response_last_campaign)) OVER (), 1) AS pct_of_all_acceptances,
       ROUND(100 * AVG(response_last_campaign), 1) AS last_campaign_rate_pct,
       ROUND(AVG(total_spend), 0)                  AS avg_spend
FROM vw_dim_customer
GROUP BY segment;

-- A5  Are previous acceptors more likely to accept the last campaign?
SELECT prior_acceptor_segment,
       COUNT(*)                                    AS customers,
       SUM(response_last_campaign)                 AS accepted_last,
       ROUND(100 * AVG(response_last_campaign), 1) AS last_campaign_rate_pct
FROM vw_dim_customer
GROUP BY prior_acceptor_segment
ORDER BY prior_acceptor_segment;

-- A5b  Same question per earlier campaign: last-campaign rate among
--      people who accepted campaign N vs. those who did not (self-join).
SELECT c.campaign_name                                            AS earlier_campaign,
       ROUND(100 * AVG(CASE WHEN f.accepted = 1 THEN l.accepted END), 1) AS last_rate_if_accepted_pct,
       ROUND(100 * AVG(CASE WHEN f.accepted = 0 THEN l.accepted END), 1) AS last_rate_if_not_pct
FROM vw_fact_campaign_response f
JOIN vw_fact_campaign_response l
  ON l.customer_id = f.customer_id AND l.campaign_key = 6
JOIN dim_campaign c ON c.campaign_key = f.campaign_key
WHERE f.campaign_key BETWEEN 1 AND 5
GROUP BY c.campaign_key, c.campaign_name
ORDER BY c.campaign_key;

-- =====================================================================
-- B. CHANNEL PERFORMANCE
-- =====================================================================

-- B1  Purchase volume and share by channel (window function for share).
SELECT ch.channel_name,
       SUM(f.purchase_count)                                          AS purchases,
       ROUND(100 * SUM(f.purchase_count) / SUM(SUM(f.purchase_count)) OVER (), 1) AS share_pct,
       ROUND(AVG(f.purchase_count), 2)                                AS avg_per_customer,
       SUM(f.purchase_count = 0)                                      AS customers_never_used
FROM vw_fact_channel_purchases f
JOIN dim_channel ch ON ch.channel_key = f.channel_key
GROUP BY ch.channel_key, ch.channel_name
ORDER BY purchases DESC;

-- Deals (discounted purchases) - reported separately, not as a channel.
SELECT SUM(num_deals_purchases)                                         AS deal_purchases,
       ROUND(100 * SUM(num_deals_purchases) / SUM(total_purchases), 1) AS deals_as_pct_of_purchases
FROM vw_dim_customer;

-- B2  Spend "associated with" each channel.
--     IMPORTANT LIMITATION: spend is recorded per PRODUCT, not per
--     channel, so channel revenue cannot be calculated. The defensible
--     alternative: average spend of customers by their preferred channel.
SELECT preferred_channel,
       COUNT(*)                          AS customers,
       ROUND(AVG(total_spend), 0)        AS avg_total_spend,
       ROUND(AVG(avg_spend_per_purchase),1) AS avg_spend_per_purchase,
       ROUND(100 * AVG(response_last_campaign), 1) AS last_campaign_rate_pct
FROM vw_dim_customer
GROUP BY preferred_channel
ORDER BY avg_total_spend DESC;

-- B3  Channel mix by segment (which segments prefer which channel).
SELECT d.income_band,
       ROUND(100 * SUM(CASE WHEN f.channel_key = 1 THEN f.purchase_count END) / SUM(f.purchase_count), 1) AS web_share_pct,
       ROUND(100 * SUM(CASE WHEN f.channel_key = 2 THEN f.purchase_count END) / SUM(f.purchase_count), 1) AS catalog_share_pct,
       ROUND(100 * SUM(CASE WHEN f.channel_key = 3 THEN f.purchase_count END) / SUM(f.purchase_count), 1) AS store_share_pct,
       ROUND(AVG(d.num_deals_purchases), 2) AS avg_deal_purchases
FROM vw_fact_channel_purchases f
JOIN vw_dim_customer d ON d.customer_id = f.customer_id
GROUP BY d.income_band, d.income_band_order
ORDER BY d.income_band_order;

SELECT d.has_children,
       ROUND(100 * SUM(CASE WHEN f.channel_key = 1 THEN f.purchase_count END) / SUM(f.purchase_count), 1) AS web_share_pct,
       ROUND(100 * SUM(CASE WHEN f.channel_key = 2 THEN f.purchase_count END) / SUM(f.purchase_count), 1) AS catalog_share_pct,
       ROUND(100 * SUM(CASE WHEN f.channel_key = 3 THEN f.purchase_count END) / SUM(f.purchase_count), 1) AS store_share_pct,
       ROUND(AVG(d.num_deals_purchases), 2) AS avg_deal_purchases
FROM vw_fact_channel_purchases f
JOIN vw_dim_customer d ON d.customer_id = f.customer_id
GROUP BY d.has_children;

-- B4  Underutilised web channel: frequent visitors who rarely buy online.
--     Visits are "last month" and purchases are "last 2 years", so this
--     is NOT a conversion rate - it is a list of customers to investigate.
SELECT CASE WHEN d.num_web_visits_month >= 7 THEN 'High visits (7+/month)'
            ELSE 'Lower visits (0-6/month)' END              AS web_visit_level,
       COUNT(*)                                              AS customers,
       ROUND(AVG(s.num_web_purchases), 2)                    AS avg_web_purchases,
       ROUND(AVG(d.total_spend), 0)                          AS avg_total_spend,
       ROUND(AVG(d.income), 0)                               AS avg_income
FROM vw_dim_customer d
JOIN stg_marketing_customers s ON s.customer_id = d.customer_id
GROUP BY web_visit_level;

-- =====================================================================
-- C. CUSTOMER VALUE
-- =====================================================================

-- C1  Spend by segment.
SELECT income_band,
       COUNT(*)                         AS customers,
       ROUND(AVG(total_spend), 0)       AS avg_spend,
       SUM(total_spend)                 AS total_spend,
       ROUND(100 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 1) AS share_of_spend_pct
FROM vw_dim_customer
GROUP BY income_band, income_band_order
ORDER BY income_band_order;

SELECT children_at_home, COUNT(*) AS customers, ROUND(AVG(total_spend), 0) AS avg_spend
FROM vw_dim_customer GROUP BY children_at_home ORDER BY children_at_home;

SELECT spend_quartile, COUNT(*) AS customers,
       SUM(total_spend) AS total_spend,
       ROUND(100 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 1) AS share_of_spend_pct
FROM vw_dim_customer GROUP BY spend_quartile, spend_quartile_order ORDER BY spend_quartile_order;

-- C2  Product spend ranking.
SELECT p.product_name,
       SUM(f.spend_amount)                                             AS total_spend,
       ROUND(100 * SUM(f.spend_amount) / SUM(SUM(f.spend_amount)) OVER (), 1) AS share_pct,
       ROUND(AVG(f.spend_amount), 1)                                   AS avg_per_customer,
       SUM(f.spend_amount > 0)                                         AS buying_customers
FROM vw_fact_product_spend f
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.product_key, p.product_name
ORDER BY total_spend DESC;

-- C3  Income vs spend: Pearson correlation computed with aggregates
--     (excludes NULL/placeholder income).
WITH x AS (
    SELECT income, total_spend FROM vw_dim_customer WHERE income IS NOT NULL
)
SELECT COUNT(*) AS customers_used,
       ROUND((AVG(income * total_spend) - AVG(income) * AVG(total_spend))
             / (STDDEV_POP(income) * STDDEV_POP(total_spend)), 3) AS pearson_r_income_spend
FROM x;

-- C4  Highest purchase activity: top 10 customers by purchases (ties ranked).
SELECT *
FROM (
    SELECT customer_id, total_purchases, total_spend, income_band, preferred_channel,
           DENSE_RANK() OVER (ORDER BY total_purchases DESC) AS activity_rank
    FROM vw_dim_customer
) ranked
WHERE activity_rank <= 3
ORDER BY activity_rank, total_spend DESC;

-- C5  Disengaged customers.
--     Definition (transparent, data-supported): last purchase 61+ days ago
--     AND never accepted any of the six campaigns.
SELECT spend_quartile,
       COUNT(*)                                                  AS customers,
       SUM(recency_days > 60 AND accepted_any_campaign = 0)      AS disengaged,
       ROUND(100 * AVG(recency_days > 60 AND accepted_any_campaign = 0), 1) AS disengaged_pct
FROM vw_dim_customer
GROUP BY spend_quartile, spend_quartile_order
ORDER BY spend_quartile_order;

-- C5b  Recency band vs last campaign response.
SELECT recency_band, COUNT(*) AS customers,
       ROUND(100 * AVG(response_last_campaign), 1) AS last_campaign_rate_pct,
       ROUND(AVG(total_spend), 0) AS avg_spend
FROM vw_dim_customer
GROUP BY recency_band, recency_band_order
ORDER BY recency_band_order;

-- C6  Enrollment cohort view. Spend is cumulative over the "last 2 years",
--     so newer cohorts have had less time to spend - NOT a time trend.
SELECT YEAR(enrollment_date)       AS enrollment_year,
       COUNT(*)                    AS customers,
       ROUND(AVG(tenure_days), 0)  AS avg_tenure_days,
       ROUND(AVG(total_spend), 0)  AS avg_spend,
       ROUND(100 * AVG(response_last_campaign), 1) AS last_campaign_rate_pct
FROM vw_dim_customer
GROUP BY YEAR(enrollment_date)
ORDER BY enrollment_year;

-- C7  Geography (with data-quality caveat column).
SELECT country,
       COUNT(*)                                     AS customers,
       ROUND(AVG(total_spend), 0)                   AS avg_spend,
       ROUND(100 * AVG(response_last_campaign), 1)  AS last_campaign_rate_pct,
       SUM(dq_country_conflict)                     AS customers_with_unverified_country,
       CASE WHEN COUNT(*) < 30 THEN 'small sample' ELSE '' END AS caution
FROM vw_dim_customer
GROUP BY country
ORDER BY customers DESC;

-- C8  Complaints.
SELECT SUM(complain) AS complaints, ROUND(100 * AVG(complain), 2) AS complaint_rate_pct
FROM vw_dim_customer;
