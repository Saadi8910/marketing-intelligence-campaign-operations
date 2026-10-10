# Business Recommendations

**Population:** 2,058 customers after removing 182 suspected duplicate rows. **Evidence:** `sql/05_marketing_analysis.sql` and `sql/06_kpi_queries.sql`; every number below can be reproduced by running those scripts.

**How to read this:** the dataset is a single snapshot with no campaign costs, dates or control groups. Findings are **associations**, not proven causes. Recommendations are therefore framed as targeting priorities and **tests to run**, not guaranteed results. Spend units are as delivered in the source (currency not stated).

---

## 1. Past responders are the strongest signal for future response

**Finding:** customers who accepted earlier campaigns are far more likely to accept the last campaign.

**Evidence (query A5, A5b):**

| Prior campaigns accepted (1–5) | Customers | Last-campaign rate |
|---|---|---|
| 0 | 1,627 | 8.5% |
| 1 | 304 | 31.3% |
| 2+ | 127 | 63.0% |

Prior acceptors respond at 40.6% vs 8.48% — a **4.79× lift**. The pattern holds for every individual campaign: acceptors of Campaign 1–5 responded to the last campaign at 36–73%, non-acceptors at 12–15%.

**Business implication:** response history is a cheap, already-available targeting variable. 431 prior acceptors (21% of customers) produced 175 of the 313 last-campaign acceptances (56%).

**Recommended action:** build a "prior responder" audience as the first-priority list for the next campaign. For the 1,627 never-responders, test a lower-cost contact strategy rather than full campaign spend, and compare results against a held-out group.

---

## 2. A small, well-defined segment drives over a third of responses

**Finding:** the income effect only appears in households **without children**. Among households with children, response is ~9–12% at every income band up to 90k.

**Evidence (query A3b, A3c):**

| Income band | No children | With children |
|---|---|---|
| 30k–50k | 25.5% (n = 55) | 11.0% (n = 575) |
| 50k–70k | 19.7% (n = 117) | 8.9% (n = 482) |
| 70k–90k | 32.2% (n = 286) | 11.5% (n = 130) |
| 90k+ | 53.3% (n = 45) | 16.7% (n = 6, small sample) |

Combined segment **"income ≥ 70k and no children at home"**: 331 customers (16.1% of the base), 35.1% response vs 11.4% for everyone else, average spend 1,464 vs 442, and **37.1% of all last-campaign acceptances**.

**Business implication:** looking at income alone would over-target high-income families, who respond like everyone else. The combination of the two attributes is what identifies the responsive group.

**Recommended action:** use "70k+ income and no children" as a priority segment for offers similar to the last campaign. For families, test a different offer type (see finding 6 on deals) instead of repeating the same campaign.

---

## 3. Campaign performance varies twelve-fold

**Finding:** the last campaign performed best; Campaign 2 performed worst by a wide margin.

**Evidence (query A1):** Last Campaign 15.21% (313) · Cmp 4 7.68% · Cmp 3 7.34% · Cmp 5 7.19% · Cmp 1 6.56% · **Cmp 2 1.26% (26)**. Overall rate across all six: 7.54%. Campaign 2 is the only check that breaks the n8n "weakest campaign < 2%" threshold.

**Business implication:** the dataset does not contain campaign content, channel, timing or cost, so it cannot explain *why* Campaign 2 underperformed. It does show that campaign design matters more than audience alone, because all six campaigns reached the same customer base.

**Recommended action:** before re-using any element of Campaign 2, review its offer, channel and timing with the campaign owner and compare them with the last campaign. Add campaign metadata (cost, channel, dates, offer type) to the data model so the next analysis can explain performance and calculate ROI.

---

## 4. Revenue is concentrated in two products and one quarter of customers

**Finding:** wines and meat make up 77.8% of spend; the top 25% of customers generate 61.6% of it.

**Evidence (queries C1, C2):** Wines 625,471 (50.1%) · Meat 345,136 (27.7%) · Gold 7.2% · Fish 6.2% · Sweets 4.5% · Fruits 4.3%. Spend quartiles: Top 25% → 61.6%, Upper-mid → 29.1%, Lower-mid → 7.6%, Bottom → 1.6%. Income and total spend are strongly correlated (Pearson r = 0.79, n = 2,033).

**Business implication:** the business is exposed to two categories and to a few hundred customers. Losing top-quartile customers has an outsized effect on revenue.

**Recommended action:** treat top-quartile retention as a standing KPI (it is on page 3). Use wine- and meat-led offers for the high-value segment; for smaller categories (fruits, sweets, fish) investigate whether low spend reflects low demand or low visibility before investing in promotion.

---

## 5. Recency predicts response, but lapsing customers are not low-value

**Finding:** recently active customers respond much more, yet average spend is the same in every recency band.

**Evidence (query C5b):**

| Recency band | Customers | Last-campaign rate | Avg spend |
|---|---|---|---|
| Active (0–30 days) | 667 | 24.3% | 603 |
| Cooling (31–60 days) | 602 | 14.1% | 593 |
| Lapsing (61–99 days) | 789 | 8.4% | 619 |

202 top-quartile customers are in the lapsing band. 602 customers (29.25%) are *disengaged* (lapsing and never accepted a campaign).

**Business implication:** campaign timing relative to a customer's last purchase appears to matter. Lapsing customers still carry the same value, so they are a re-engagement opportunity, not a write-off. (Recency is a single snapshot, so this cannot prove churn.)

**Recommended action:** schedule offers soon after purchase activity where possible. Create a re-engagement test for the 202 high-value lapsing customers and track whether their recency improves on the next data refresh.

---

## 6. Families use discounts more; high-income customers rarely do

**Finding:** deal usage differs strongly by household and income.

**Evidence (query B3):** households with children average 2.80 deal purchases vs 1.15 without. By income band: 50k–70k 2.98 · 30k–50k 2.51 · <30k 2.13 · 70k–90k 1.45 · 90k+ 1.12. Deals are 18.7% of all purchases.

**Business implication:** discount-led offers fit families and mid-income customers; for high-income, no-children customers (finding 2), discounts would likely give away margin to people who respond without them.

**Recommended action:** test a deal-based offer for families (the group with low response to the existing campaigns) and a non-discount, product-led offer for the high-income segment.

---

## 7. Catalog: low volume, high-value users, large non-user base

**Finding:** catalog is the smallest channel by volume, but customers who prefer it are the most valuable and most responsive.

**Evidence (queries B1, B2, B3):** purchase share Store 46.1% · Web 32.7% · Catalog 21.2%. 537 customers (26.1%) have never used the catalog — 64.7% of <30k and 43.5% of 30k–50k customers, but only 5.0% of 50k–70k. Catalog-preferring customers average 1,367 spend and 35.2% last-campaign response (store-preferring: 554 and 10.4%). Catalog share of purchases rises from 9.2% (<30k) to 35.9% (90k+).

**Business implication:** catalog behaves like a premium channel. Its higher value is probably linked to the income of its users rather than to the channel itself, so pushing catalog to low-income customers is unlikely to produce the same results.

**Recommended action:** keep catalog focused on 50k+ customers. If catalog costs are known, compare cost per purchase by channel before deciding on expansion; the dataset has no cost data, so this cannot be calculated here.

---

## 8. Frequent website visitors are lower-value and don't buy more online

**Finding:** customers visiting the website 7+ times a month spend less and buy online slightly less than infrequent visitors.

**Evidence (query B4):** 761 customers with 7+ visits: average spend 322, average income 38,604, 3.82 web purchases. 1,297 customers with 0–6 visits: spend 773, income 59,952, 4.26 web purchases.

**Business implication:** high browsing does not translate into online purchasing. Because visits cover *last month* and purchases cover *two years*, no conversion rate can be calculated, so this is a lead to investigate rather than a measured funnel problem.

**Recommended action:** with web analytics data (sessions, carts, checkouts), check whether frequent visitors are price-checking or dropping out at checkout. This would be the first data source to add to the model.

---

## 9. Data quality would have overstated totals by 8.8%

**Finding:** 182 rows (8.1% of the file) are copies of another customer except for ID and country.

**Evidence (03 DQ-09, 06 Part 2):** without de-duplication the report would show 2,240 customers and 1,356,988 spend instead of 2,058 and 1,247,643 (+8.8%). Average spend (605.80 vs 606.24) and response rate (14.91% vs 15.21%) barely change, which is why this kind of problem goes unnoticed. 131 duplicate groups disagree on country.

**Business implication:** any total-based KPI (customer count, revenue, campaign reach) would be wrong, and country-level results are uncertain for 6.4% of customers.

**Recommended action:** raise the duplicate-profile issue with the data owner and fix it at source; until then keep the automated n8n check, which flags the problem on every run. Treat country-level comparisons as indicative.

---

## Secondary observations (reported, not acted on)

| Observation | Evidence | Why it is not a separate recommendation |
|---|---|---|
| PhD holders respond more (20.7%) than Basic education (4.1%) | Query A3 | Education is linked to income (Basic avg income 19,913 vs PhD 55,961) and Basic n = 49; likely the income effect again |
| Not-partnered customers respond more (22.2% vs 11.2%) | Query A3 | Worth testing as a secondary filter; not checked for interaction with income/children |
| 65+ (24.0%) and 18–34 (19.8%) respond more than middle ages (13–14%) | Query A3 | 65+ has 96 customers; needs validation on more data |
| 2012 enrollees respond at 27.4% vs 9.3% for 2014 | Query C6 | Strongly confounded with tenure; newer customers have had less time with the brand |
| Country differences are small (9.0%–16.6%, excl. Mexico) | Query C7 | Within data-quality uncertainty; Mexico n = 2 |
| Complaint rate is 0.97% (20 customers) | Query C8 | Too few to segment |
