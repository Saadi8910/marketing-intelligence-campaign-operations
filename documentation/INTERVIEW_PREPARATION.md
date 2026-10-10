# Interview Preparation — Marketing Intelligence & Campaign Operations

Answers are written in the first person and based on this project. Keep each spoken answer to roughly 60–90 seconds; the bold sentence is the one-line version.

---

### 1. Why did you choose this data model?
**The source is one wide row per customer, so I unpivoted campaigns, products and channels into three narrow fact tables that share one Customer dimension.**
With the wide table, "acceptance rate by campaign" needs six measures and can't go on one chart axis. After unpivoting, one measure — `Campaign Acceptance Rate` — works for every campaign, every segment and every card. Each fact has its own grain (customer × campaign, × product, × channel) and the Customer dimension is conformed, so one Income Band slicer filters all three consistently.
I kept it simple on purpose: customer-level behaviour like recency, deals and web visits stays on the Customer table rather than in a 1:1 fact, because that would add a table without adding capability. And I documented the limitation that the Date table only covers enrollment, because there are no purchase dates.

### 2. Why did you use SQL vs Power Query?
**SQL for business rules that should exist once and be reusable; Power Query only for report-facing shaping.**
De-duplication is the best example: I partition on 26 columns with `ROW_NUMBER()` and compare `MIN(country)` vs `MAX(country)` over the same window to detect conflicts. That's natural in SQL and painful in M. Doing it in SQL also means the n8n monitoring uses the exact same rules as the dashboard.
Power Query does data types, friendly names, Yes/No labels for 0/1 flags and the generated calendar — things that only matter for how the report reads.

### 3. Why are some calculations DAX rather than SQL?
**Anything that has to respond to the user's filters is DAX.**
If I calculated acceptance rate in SQL, it would be correct only for the grouping I chose. In DAX, `DIVIDE([Campaign Acceptances], COUNTROWS('Campaign Response'))` is correct for any combination of country, income band or campaign the user picks. Conversely, a customer's income band never changes with a filter, so it's a column built in SQL, not a DAX calculated column.

### 4. How did you validate the data?
**I profiled the raw table before writing any cleaning rule, and I reconcile counts at every layer.**
`03_data_quality_checks.sql` checks keys, blanks, non-numeric values, flag domains, date parsing, ranges, category values, duplicate profiles and logical consistency between fields. The cleaning script prints a PASS/FAIL reconciliation: 2,240 raw rows = 2,240 staging rows = 2,058 reporting + 182 excluded. Then `06_kpi_queries.sql` produces expected KPI values that every DAX measure must match, for example 2,058 customers, 1,247,643 total spend and 15.21% last-campaign response.

### 5. How did you handle missing values?
**Only Income had missing values — 24 rows — and I left them as NULL instead of imputing.**
The raw table is all VARCHAR so blanks can't silently become zero on load. In staging, blank income becomes NULL and the income band becomes "Unknown". These customers still count in spend, campaigns and channels; they're only excluded from income averages, and DAX `AVERAGE` ignores blanks. I applied the same approach to the 666,666 placeholder income: raw value kept in `income_raw`, cleaned `income` set to NULL. Imputation would add an assumption without changing any conclusion for 1% of rows.

### 6. How did you identify anomalies?
**A mix of range checks, gap analysis and cross-field consistency checks.**
For income, a window query with `LEAD()` showed the top value was 4.1× the next — that's the 666,666 placeholder. For birth year, 1893/1899/1900 had a 40-year gap to the next value. For consistency, I checked fields that should agree: 6 customers have spend but zero purchases, and 3 have more deal purchases than total purchases. The biggest anomaly wasn't an outlier at all: 182 rows were identical to another customer on every field except ID and country. A simple ID uniqueness check passes, so you only find it by grouping on the full profile.

### 7. Explain your most important DAX measure.
**`Campaign Acceptance Rate`, and the cross-fact `Spend of Campaign Acceptors` that builds on the model design.**
`Campaign Acceptance Rate = DIVIDE([Campaign Acceptances], COUNTROWS('Campaign Response'))` — acceptances divided by customer-campaign offers in context. On a bar by campaign it's each campaign's rate; on a card it's the blended 7.54%.
The more interesting one is `Spend of Campaign Acceptors`. Filters only flow from dimensions to facts, so selecting Campaign 4 doesn't filter Product Spend. I use `CALCULATETABLE(VALUES('Campaign Response'[Customer ID]), 'Campaign Response'[Accepted] = 1)` to get the acceptors and `TREATAS` to apply them to `Customer[Customer ID]`, which then filters spend. That answers "how valuable are this campaign's responders?" without bi-directional relationships. For the last campaign it shows acceptors average 980 spend vs 539 for non-acceptors.

### 8. How would a marketing manager use this dashboard?
**Page 1 in a weekly review, page 2 when planning the next campaign's audience, page 3 before trusting a number.**
On page 1 they see in seconds that the last campaign achieved 15.2% while Campaign 2 managed 1.3%, and that store drives 46% of purchases. On page 2 they'd select "2+ prior acceptances" and see 63% response, or look at the income × campaign heatmap to choose a target segment — for example, 70k+ customers without children are 16% of the base but produced 37% of last-campaign acceptances. Page 3 tells them how many high-value customers are lapsing (202) and shows, in the attention panel, that 182 duplicate rows were excluded and 131 countries are unverified, so they know where the numbers are softer.

### 9. How does the n8n workflow work?
**Schedule → one SQL query → log everything → route alerts → one consolidated notification.**
A daily trigger runs `SELECT * FROM vw_monitoring_checks`, which returns nine rows: six data-quality checks and three KPI checks, each with value, threshold and OK/ALERT status. Every row is inserted into `monitoring_log` for history. An IF node sends ALERT rows to a Code node that combines them into one message, then to a notification node. The notification is a placeholder because I didn't commit email or Slack credentials; swapping in a Gmail or Slack node is a two-field mapping. Thresholds live in a table, so changing a target doesn't require editing the workflow. It's a portfolio demonstration, not connected to a production system — on this static dataset it raises the same three alerts each run.

### 10. How would you productionize this solution?
**Replace the manual CSV step with scheduled ingestion, move to a governed database and Power BI Service, and add ownership.**
Concretely: load new extracts automatically into `raw_` with a load timestamp, and make the staging build incremental; run the scripts from a scheduler or pipeline and stop the refresh if the reconciliation fails; host MySQL on a managed server with a read-only reporting user and an on-premises data gateway for Power BI scheduled refresh; use Power BI deployment pipelines (dev/test/prod) and save the report as a .pbip project so changes are reviewed in Git; agree thresholds and an owner for every alert; and fix the duplicate issue at source with a uniqueness rule rather than relying on downstream cleaning.

### 11. How would you improve Power BI performance?
**Keep the model narrow and the measures simple — most of that is already in this project.**
Import mode, integer keys, only needed columns, auto date/time off, single-direction relationships, row logic pushed to SQL rather than calculated columns, and measures using variables, `DIVIDE` and `KEEPFILTERS` instead of iterating `FILTER` over whole tables. At larger scale I'd use Performance Analyzer and DAX Studio to find slow visuals, reduce visuals per page, consider aggregations or incremental refresh for big fact tables, and query folding so Power Query transformations run in the database.

### 12. How would you implement row-level security?
**Static or dynamic roles on the Customer table, because every fact is filtered through it.**
For example, a regional manager should only see their countries. Simple version: a role with the DAX filter `Customer[Country] = "Spain"`. Scalable version: a mapping table of user email → country, related to Customer, with the role filter `UserCountry[Email] = USERPRINCIPALNAME()`. Because the facts are filtered by Customer, the three facts and all measures are secured automatically. I'd test with *View as role*. One caveat specific to this data: the 131 customers with conflicting countries would need a decision on which region owns them before RLS by country is reliable.

### 13. How would you handle a stakeholder requesting a new KPI?
**Clarify the business question and definition first, check the data supports it, then build and reconcile.**
A real example: if someone asked for "revenue by channel", I'd explain that this dataset records spend per product, not per channel, so it can't be calculated honestly. I'd offer the closest valid alternatives — channel share of purchase volume and average spend by preferred channel — and say what extra data would make the real KPI possible. If the KPI is feasible, I agree a written definition (numerator, denominator, filters, exclusions), add the measure, reconcile it against a SQL query, document it in `DAX_MEASURES.md`, and add a threshold to the monitoring table if it should be watched.

### 14. How would you troubleshoot a dashboard showing incorrect numbers?
**Work down the layers until the number matches: visual → measure → model → Power Query → SQL → source.**
1. Reproduce: note the exact filters, slicers and page; check for a hidden visual-level filter.
2. Compare against the SQL expected value in `06_kpi_queries.sql` with the same filter added.
3. Test the measure on a blank page with no filters — if it matches there, the issue is filter context (e.g. a missing `KEEPFILTERS`, or a relationship not filtering as assumed).
4. Check the model: relationship active, correct direction, correct cardinality, no duplicate keys on the "one" side.
5. Check row counts per table against the SQL views (2,058 / 12,348 / 12,348 / 6,174).
6. Check data freshness and the reconciliation output, then the DQ exceptions — a re-loaded file with duplicates would show up here and in the n8n alert.
Once found, I fix it, add a check so it can't recur silently, and tell the stakeholder what was wrong and which numbers were affected.

---

## Likely follow-ups

**"Isn't deleting 182 rows risky?"** — I didn't delete anything. All 2,240 rows stay in staging with a flag and a pointer to the ID they duplicate; reporting views filter them out. The rule is reversible and its impact is quantified: +8.8% on totals if not applied.

**"Why keep the lowest ID?"** — It's deterministic and reproducible. Nothing in the data says which copy is correct, so a stable rule plus a country-conflict flag is more honest than a guess.

**"What would you do differently?"** — Get the source owner to confirm the duplicate rule, and add campaign metadata (cost, dates, channel) so I could explain performance and calculate ROI rather than only acceptance.

**"What's the most important insight?"** — Response is concentrated and predictable: prior responders respond 4.8× more often, and 70k+ customers without children (16% of the base) delivered 37% of last-campaign acceptances. That's directly usable for targeting.

**"Why is age based on 2014?"** — The data has no extraction date; the newest enrollment is 2014-06-29, so the data can't be older than that. Using the current year would make everyone ~12 years older and break the age groups. The assumption is stated on page 3.
