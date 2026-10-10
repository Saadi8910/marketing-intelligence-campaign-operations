# Data Dictionary

**Source:** Maven Analytics — *Marketing Campaign Results* (Data Playground). File `marketing_data.csv`, with descriptions from the accompanying `marketing_data_dictionary.csv`.
**Profile:** 2,240 rows × 28 columns · UTF-8 with BOM · Windows (CRLF) line endings · one row per customer ID.
**Profiled with:** `sql/03_data_quality_checks.sql`.

Descriptions in the first table come from the source dictionary. Where a definition is ambiguous, the ambiguity is stated rather than guessed.

## 1. Source columns

| # | Column | Description (source) | Data type | Example | Potential data-quality issue | Business relevance |
|---|---|---|---|---|---|---|
| 1 | `ID` | Customer's unique identifier | Integer | 1826 | Unique (2,240 distinct), **but 182 rows are copies of another ID's full profile** (see DATA_QUALITY.md). Includes ID 0 | Primary key of the customer dimension |
| 2 | `Year_Birth` | Customer's birth year | Integer | 1970 | 3 values (1893, 1899, 1900) imply ages 114–121; next earliest is 1940 | Age-group segmentation |
| 3 | `Education` | Customer's education level | Text (5 values) | Graduation | Labels are not self-explanatory: `2n Cycle` likely means a second-cycle (Master's-level) degree, which overlaps `Master`. Kept as delivered | Segmentation; PhD holders respond most |
| 4 | `Marital_Status` | Customer's marital status | Text (8 values) | Married | Non-standard values: `Alone` (3), `YOLO` (2), `Absurd` (2) | Household segmentation |
| 5 | ` Income ` | Customer's yearly household income | Decimal | 84835 | **Header has leading/trailing spaces.** 24 blanks (1.07%). One value of 666,666 (4× the next highest). Currency not stated | Strongest single correlate of spend (r = 0.79) |
| 6 | `Kidhome` | Number of children in household | Integer (0–2) | 0 | None found | Households with no children average 1,121 spend vs 248–470 for households with children |
| 7 | `Teenhome` | Number of teenagers in household | Integer (0–2) | 1 | None found | Combined with Kidhome into *Children At Home* |
| 8 | `Dt_Customer` | Date of customer's enrollment with the company | Date (YYYY-MM-DD) | 2014-06-16 | All valid; range 2012-07-30 → 2014-06-29 | **Only date in the dataset** → Date dimension, tenure, acquisition trend |
| 9 | `Recency` | Number of days since customer's last purchase | Integer (0–99) | 0 | Relative to an unstated snapshot date, so it cannot be converted to a calendar date | Engagement / lapse risk |
| 10 | `MntWines` | Amount spent on wine in the last 2 years | Integer | 189 | Customers enrolled < 2 years ago have had less time to spend | Largest category (50.1% of spend) |
| 11 | `MntFruits` | Amount spent on fruits in the last 2 years | Integer | 104 | As above | Product mix |
| 12 | `MntMeatProducts` | Amount spent on meat in the last 2 years | Integer | 379 | As above | 2nd largest category (27.7%) |
| 13 | `MntFishProducts` | Amount spent on fish in the last 2 years | Integer | 111 | As above | Product mix |
| 14 | `MntSweetProducts` | Amount spent on sweets in the last 2 years | Integer | 189 | As above | Product mix |
| 15 | `MntGoldProds` | Amount spent on gold in the last 2 years | Integer | 218 | As above | Product mix |
| 16 | `NumDealsPurchases` | Number of purchases made with a discount | Integer (0–15) | 1 | **Overlaps the channel columns** (a deal is bought via web/catalog/store). 3 rows have more deals than total purchases | Discount dependency; not a channel |
| 17 | `NumWebPurchases` | Number of purchases through the website | Integer (0–27) | 4 | Max 27 is high but plausible | Channel volume |
| 18 | `NumCatalogPurchases` | Number of purchases using a catalogue | Integer (0–28) | 4 | Max 28 is high but plausible | Channel volume |
| 19 | `NumStorePurchases` | Number of purchases made in stores | Integer (0–13) | 6 | None found | Largest channel by volume |
| 20 | `NumWebVisitsMonth` | Visits to company website in the last month | Integer (0–20) | 1 | 9 rows > 10 visits. **Different period from purchases** → no valid conversion rate | Web interest signal |
| 21 | `AcceptedCmp3` | 1 if customer accepted the offer in the 3rd campaign | Flag 0/1 | 0 | Source column order is 3,4,5,1,2 — order was re-sequenced in `dim_campaign` | Campaign outcome |
| 22 | `AcceptedCmp4` | 1 if accepted the 4th campaign | Flag 0/1 | 0 | — | Campaign outcome |
| 23 | `AcceptedCmp5` | 1 if accepted the 5th campaign | Flag 0/1 | 0 | — | Campaign outcome |
| 24 | `AcceptedCmp1` | 1 if accepted the 1st campaign | Flag 0/1 | 0 | — | Campaign outcome |
| 25 | `AcceptedCmp2` | 1 if accepted the 2nd campaign | Flag 0/1 | 0 | — | Campaign outcome (weakest: 1.26%) |
| 26 | `Response` | 1 if accepted the offer in the **last** campaign | Flag 0/1 | 1 | Name does not say "campaign 6"; modelled as *Last Campaign (6)* | Campaign outcome (strongest: 15.21%) |
| 27 | `Complain` | 1 if customer complained in the last 2 years | Flag 0/1 | 0 | Very rare (20 customers) | Service-quality signal |
| 28 | `Country` | Customer's location | Text (8 values) | Spain | Conflicts between duplicate copies (131 groups). Mexico has only 3 rows | Geographic slicing (with caveat) |

### Column classification

| Category | Columns |
|---|---|
| Identifier | ID |
| Date | Dt_Customer |
| Categorical | Education, Marital_Status, Country |
| Numerical — demographic | Year_Birth, Income, Kidhome, Teenhome |
| Numerical — behaviour | Recency, NumWebVisitsMonth |
| Product spending | MntWines, MntFruits, MntMeatProducts, MntFishProducts, MntSweetProducts, MntGoldProds |
| Purchasing channels | NumWebPurchases, NumCatalogPurchases, NumStorePurchases (+ NumDealsPurchases as a discount attribute) |
| Campaign outcomes | AcceptedCmp1–5, Response |
| Service | Complain |

### What the dataset does **not** contain
Transaction dates, order values, channel-level revenue, campaign dates, campaign costs, targeting lists, product prices or currency. Any metric needing these (ROI, CAC, revenue by channel, sales trend) is out of scope and is not shown in the report.

## 2. Derived fields (created in `sql/04_clean_marketing_data.sql`)

| Field | Logic | Purpose |
|---|---|---|
| `age` | 2014 − Year_Birth; NULL if Year_Birth < 1920 | Reference year 2014 = year of latest enrollment (no extraction date in source) |
| `age_group` | 18-34 / 35-44 / 45-54 / 55-64 / 65+ / Unknown | Slicer |
| `marital_status` | Alone → Single; YOLO, Absurd → Unknown | Clean slicer values |
| `relationship_status` | Married/Together → Partnered; Single/Divorced/Widow/Alone → Not partnered | Simpler two-way comparison |
| `income` | NULL if blank or > 200,000 (the 666,666 placeholder) | Unbiased averages |
| `income_band` | <30k / 30k-50k / 50k-70k / 70k-90k / 90k+ / Unknown | Slicer |
| `children_at_home`, `has_children` | Kidhome + Teenhome | Household segmentation |
| `tenure_days` | Days from enrollment to 2014-06-29 | Context for "last 2 years" spend |
| `recency_band` | Active 0-30 / Cooling 31-60 / Lapsing 61-99 days | Engagement segmentation |
| `total_spend` | Sum of 6 Mnt* columns | Value KPI |
| `total_purchases` | Web + Catalog + Store (deals excluded — they overlap) | Activity KPI |
| `avg_spend_per_purchase` | total_spend / total_purchases (NULL when 0 purchases) | Basket value |
| `preferred_channel` | Channel with strictly most purchases; ties → "Tie (multi-channel)" | Channel segmentation |
| `prior_campaigns_accepted` | Sum of Cmp1–5 | Tests whether past response predicts the last campaign |
| `total_campaigns_accepted`, `accepted_any_campaign` | Cmp1–5 + Response | Engagement rate |
| `spend_quartile` | NTILE(4) on total_spend over the reporting population | Value tier |
| `duplicate_of_customer_id`, `duplicate_group_size`, `is_suspected_duplicate`, `dq_country_conflict` | Window functions over all fields except ID/Country | De-duplication and audit trail |
| `dq_*` flags, `dq_issue_count`, `include_in_reporting` | See DATA_QUALITY.md | Transparent data-quality handling |
