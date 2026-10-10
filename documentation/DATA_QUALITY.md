# Data Quality Report

> BI reporting is only as useful as the data underneath it. This document records every issue found in the source, how it was handled, and what it means for the dashboard.

**Evidence:** `sql/03_data_quality_checks.sql` (raw profiling) · `sql/04_clean_marketing_data.sql` (handling) · `vw_dq_exceptions` / `vw_dq_summary` (ongoing reporting) · `vw_monitoring_checks` (n8n alerting).

## Guiding rules

1. **Never delete source data.** All 2,240 rows remain in `stg_marketing_customers`. Rows are *flagged*, and the reporting views filter on `include_in_reporting = 1`.
2. **Keep the raw value next to the cleaned value** whenever a rule changes it (`income_raw` / `income`, `marital_status_raw` / `marital_status`).
3. **Prefer NULL/"Unknown" over invented values.** No imputation: with 25 affected customers, imputing would add assumptions without changing any conclusion.
4. **Reconcile every step.** Raw rows = staging rows = reporting rows + excluded rows (2,240 = 2,058 + 182). The script prints PASS/FAIL.
5. **Show the caveats in the report itself** (page 3 attention panel, tooltips), not only in documentation.

## Summary

| # | Issue | Rows | Severity | Handling | In reporting? |
|---|---|---|---|---|---|
| 1 | Suspected duplicate customer profiles | 182 surplus rows (176 groups) | **High** | Lowest ID kept; others excluded | Excluded |
| 2 | Country conflicts within duplicate groups | 131 surviving customers | Medium | Kept; flagged "Unverified" | Included, flagged |
| 3 | Missing income | 24 | Medium | NULL; band "Unknown" | Included |
| 4 | Income placeholder outlier (666,666) | 1 | Medium | Income → NULL; raw kept | Included |
| 5 | Implausible birth years (1893, 1899, 1900) | 3 | Medium | Age → NULL; group "Unknown" | Included |
| 6 | Non-standard marital status | 7 (4 invalid + 3 "Alone") | Low | YOLO/Absurd → Unknown; Alone → Single | Included |
| 7 | Spend recorded with zero purchases | 6 | Low | Flagged; avg basket NULL | Included |
| 8 | Deal purchases > total purchases | 3 | Low | Flagged | Included |
| 9 | Web visits > 10 in a month | 9 | Low | Flagged only (plausible) | Included |
| 10 | Messy header / file format (BOM, CRLF, `" Income "`) | file-level | Low | Handled in load script | n/a |
| 11 | Small-sample segment (Mexico, n = 3 → 2) | 3 | Low | Tooltip warning | Included |
| — | Missing values in any other column | 0 | — | — | — |
| — | Campaign flags outside 0/1, or blank | 0 | — | Monitored by n8n | — |
| — | Unparseable dates | 0 | — | — | — |
| — | Duplicate IDs | 0 | — | — | — |

## Detail per issue

### 1. Suspected duplicate customer profiles — HIGH
**What was found?** IDs are unique, so a naïve key check passes. However, 358 rows fall into 176 groups whose members are **identical on all 26 non-ID fields except Country**: same birth year, income, enrollment date, recency, all six product amounts, all five purchase/visit counts, all six campaign flags and the complaint flag. 170 groups are pairs and 6 are triples, giving 182 surplus rows. Only 47 of the surplus rows also match on country.
*Example:* IDs 4047 and 9477 — both born 1954, PhD, married, income 65,324, enrolled 2014-01-11, identical spend — one listed in the USA, the other in India.

**Why is it a problem?** Two genuine customers matching on ~25 values (including exact income and exact amounts in six categories) is not realistic. Counting both inflates customers and spend and double-weights these profiles in every rate.

**How was it handled?** A window function partitions on every field except ID and Country. `ROW_NUMBER()` keeps the **lowest ID** in each group (deterministic, reproducible). Surplus rows get `is_suspected_duplicate = 1` and `include_in_reporting = 0`; `duplicate_of_customer_id` records which ID each was matched to. In production the rule would be confirmed with the source-system owner — the word *suspected* is deliberate.

**Impact on the dashboard.** Measured in `06_kpi_queries.sql` Part 2:

| Population | Customers | Total spend | Avg spend | Last-campaign rate |
|---|---|---|---|---|
| Deduplicated (reported) | 2,058 | 1,247,643 | 606.24 | 15.21% |
| All raw rows | 2,240 | 1,356,988 | 605.80 | 14.91% |

Without de-duplication, **customer count and total spend would be overstated by 8.8%**. Averages and rates barely move, which is exactly why this issue is easy to miss: it only shows up in totals.

### 2. Country conflicts — MEDIUM
**What?** In 131 of the 176 duplicate groups, the copies list different countries. **Why a problem?** The surviving row's country is effectively a coin flip between the copies, so geographic results carry uncertainty for 131 customers (6.4% of the reporting base). **Handling:** kept, flagged `dq_country_conflict = 1`; Power Query adds `Country Status = "Unverified (conflicting duplicates)"`. **Impact:** geographic visuals on page 2 include an "Unverified country" count in the tooltip, and country-level conclusions are presented as indicative only.

### 3. Missing income — MEDIUM
**What?** 24 blanks (1.07%). **Why?** Loading blanks into a numeric column silently becomes 0 in many tools, which would drag average income down. That is why the raw table is VARCHAR. **Handling:** cast to NULL; `income_band = "Unknown"`; DAX `AVERAGE` ignores blanks. Rows stay in all non-income metrics. **Impact:** the Unknown band (25 customers, incl. issue 4) is shown with a small-sample note; average income is based on 2,033 customers.

### 4. Income placeholder outlier — MEDIUM
**What?** One customer (ID 9432) has income 666,666 — 4.1× the next-highest value (162,397) and a repeated-digit pattern typical of placeholder entries; the customer's total spend (62) is inconsistent with that income. **Why?** One value shifts mean income and distorts the income-vs-spend scatter axis. **Handling:** `income_raw` keeps 666,666; `income` = NULL; band = Unknown. The rule is `income > 200,000`, so it would also catch similar future entries. **Impact:** scatter and income averages are not distorted. Seven other incomes of ~153–162k are kept: they are plausible, although four of them (IDs 1503, 5336, 11181, 5555) have total spend of 6–107, which is worth a business review.

### 5. Implausible birth years — MEDIUM
**What?** 1893, 1899, 1900 → ages 114–121 at the 2014 reference year. There is a clean gap to 1940 (age 74). **Why?** Would create a fake "100+" segment and inflate average age. **Handling:** rule `Year_Birth < 1920` → `age = NULL`, `age_group = "Unknown"`. Customers stay in all other metrics. **Impact:** 3 customers in "Unknown" age group (hidden by default in age visuals).

**Reference-date assumption.** The dataset has no extraction date. Age and tenure use **2014-06-29**, the latest enrollment date, because the data cannot be older than its newest customer. This is an assumption, stated on the report.

### 6. Non-standard marital status — LOW
**What?** `YOLO` (2), `Absurd` (2), `Alone` (3). **Why?** Each label becomes its own slicer item and a 2-row "segment" with a meaningless rate. **Handling:** `Alone` → Single (same meaning); `YOLO`/`Absurd` → Unknown (no defensible mapping). Raw value preserved. **Impact:** clean five-value slicer plus Unknown.

### 7. Spend with zero purchases — LOW
**What?** 6 customers have product spend (5–9 units) but 0 web, catalog and store purchases; two of them have 15 deal purchases. **Why?** Fields that should agree don't; basket value would divide by zero. **Handling:** flagged; `avg_spend_per_purchase = NULL`. **Impact:** negligible on totals; listed in the exceptions table for follow-up.

### 8. Deals exceed purchases — LOW
**What?** 3 customers have more discounted purchases than total channel purchases. **Why?** If deals are a subset of purchases, this is impossible, which suggests the fields are captured inconsistently. **Handling:** flagged. It is also the reason deals are **not** added to channel totals anywhere in the model.

### 9. Web-visit outliers — LOW
**What?** 9 customers with 13–20 visits last month (99.5% of rows have ≤ 9). Most have 0–1 web purchases and low spend. **Handling:** flagged only — high browsing is plausible. **Impact:** none on totals; useful context for the "browsers who don't buy" observation.

### 10. File-format issues — LOW
UTF-8 BOM on the first header, CRLF line endings and a padded `" Income "` header. Handled in `02_create_raw_table.sql` (`IGNORE 1 LINES`, `LINES TERMINATED BY '\r\n'`, explicit column mapping). A row-count reconciliation (2,240 expected) prints PASS/FAIL.

### 11. Small samples — LOW
Mexico has 3 rows (2 after de-duplication), so its 50% response rate is two customers. Any segment with n < 30 shows a tooltip warning (`Small Sample Warning` measure) and is labelled "small sample" in SQL outputs.

## Checks that passed
No duplicate IDs · no NULLs outside Income · all numeric columns are numeric · all campaign/complaint flags are 0 or 1 · all dates parse · Kidhome/Teenhome are 0–2 · Recency is 0–99 · no negative amounts · every customer has spend > 0.

## Structural limitations (not errors, but they constrain reporting)
- Spend is per product and "last 2 years"; there are **no transaction dates** → no sales trend, no time intelligence on spend.
- No channel-level revenue → channel analysis uses purchase counts only.
- No campaign dates, costs, or targeting lists → acceptance rates assume every customer received every campaign; ROI is not calculable.
- Customers enrolled in 2014 have < 1 year of tenure but are compared with customers enrolled in 2012 on a "last 2 years" spend window, so tenure partly explains spend differences between enrollment cohorts.

## Ongoing monitoring
The same rules run as automated checks in `vw_monitoring_checks` (thresholds in `monitoring_thresholds`), executed on a schedule by the n8n workflow. On the current static dataset, 3 checks raise ALERT (duplicates, invalid birth years, weakest campaign < 2%) and 6 are OK.
