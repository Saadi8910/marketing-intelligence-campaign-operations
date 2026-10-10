# DAX Measures

All measures live in a dedicated `_Measures` table (Home → Enter data → one dummy column, then hide it). Measures are grouped into display folders matching the sections below.

**Validation rule:** every measure has an *expected value* at the unfiltered level, taken from `sql/06_kpi_queries.sql`. If a card in Power BI does not show this number, the model or the measure is wrong. This SQL ↔ DAX reconciliation is the project's main accuracy control.

**Table and column names** follow the Power Query output (`powerbi/power_query/*.pq`): `Customer`, `Campaign`, `Product`, `Channel`, `Date`, `Campaign Response`, `Product Spend`, `Channel Purchases`, `DQ Exceptions`, `DQ Summary`.

---

## Which metrics from the brief are possible?

| Requested metric | Possible? | Notes |
|---|---|---|
| Total Customers | ✅ | 2,058 after de-duplication |
| Total Spending | ✅ | Sum of 6 product amounts ("last 2 years" per source dictionary) |
| Average Customer Spend | ✅ | |
| Total Web / Store / Catalog Purchases | ✅ | Purchase **counts**, not revenue |
| Total Deal Purchases | ✅ | Kept separate: deals overlap the three channels |
| Campaign Acceptance Count / Rate | ✅ | Per campaign and overall |
| Average Web / Store / Catalog / Deal Purchases | ✅ | Per customer |
| Customer Engagement Rate | ✅ (defined) | Defined here as % of customers accepting ≥1 campaign; the source has no engagement field, so the definition is explicit |
| Recency metrics | ✅ | Days since last purchase; no purchase *date* exists |
| Product spending metrics | ✅ | |
| Channel contribution | ⚠️ Partial | Share of purchase **count** only. **Channel revenue cannot be calculated**: spend is recorded per product, not per channel |
| Spending trend over time | ❌ | No transaction dates. Only an enrollment-date trend (customer acquisition) is possible |
| Campaign ROI / cost / revenue per campaign | ❌ | No cost or campaign-revenue fields |
| Conversion rate (web visits → purchases) | ❌ | Visits are "last month", purchases are "last 2 years": different periods, so a ratio would be misleading |

---

## 1. Customer & Spend

### Total Customers
```dax
Total Customers = COUNTROWS ( Customer )
```
**Measures:** customers in the reporting population (one row per de-duplicated customer).
**Why it matters:** the denominator for every rate. Because filters flow *from* Customer *to* the facts, slicing by Campaign/Product/Channel does not change it — which is what we want for "% of customers" style rates.
**Expected:** 2,058

### Total Spending
```dax
Total Spending = SUM ( 'Product Spend'[Spend Amount] )
```
**Measures:** total spend across the six product categories (source period: last 2 years).
**Why it matters:** the headline value metric. Responds to the Product slicer because it reads from the product fact.
**Expected:** 1,247,643 (format as whole number; the source does not state the currency, so no currency symbol is shown).

### Average Customer Spend
```dax
Average Customer Spend = DIVIDE ( [Total Spending], [Total Customers] )
```
**Measures:** spend per customer in the current filter context. `DIVIDE` returns BLANK instead of an error when there are no customers.
**Why it matters:** comparable across segments of different size (unlike Total Spending).
**Expected:** 606.24

### Average Income
```dax
Average Income = AVERAGE ( Customer[Income] )
```
**Measures:** mean of known incomes. The 24 blank incomes and the 666,666 placeholder are NULL after cleaning, and `AVERAGE` ignores blanks.
**Expected:** 52,056 (2,033 customers with known income).

### Spend per Purchase
```dax
Spend per Purchase =
DIVIDE ( [Total Spending], CALCULATE ( [Total Channel Purchases], REMOVEFILTERS ( Channel ) ) )
```
**Measures:** average basket value. Channel filter removed from the denominator because spend cannot be split by channel.
**Expected:** 48.38

### Top Quartile Spend Share %
```dax
Top Quartile Spend Share % =
DIVIDE (
    CALCULATE ( [Total Spending], Customer[Spend Quartile] = "Top 25%" ),
    CALCULATE ( [Total Spending], REMOVEFILTERS ( Customer[Spend Quartile] ) )
)
```
**Measures:** how concentrated revenue is in the best 25% of customers.
**Why it matters:** concentration drives retention priorities — losing a top-quartile customer costs far more than an average one.
**Expected:** 61.6%

---

## 2. Channel

### Total Channel Purchases
```dax
Total Channel Purchases = SUM ( 'Channel Purchases'[Purchase Count] )
```
**Expected:** 25,787 (web + catalog + store; deals are excluded to avoid double counting).

### Web / Catalog / Store Purchases
```dax
Web Purchases     = CALCULATE ( [Total Channel Purchases], KEEPFILTERS ( Channel[Channel] = "Web" ) )
Catalog Purchases = CALCULATE ( [Total Channel Purchases], KEEPFILTERS ( Channel[Channel] = "Catalog" ) )
Store Purchases   = CALCULATE ( [Total Channel Purchases], KEEPFILTERS ( Channel[Channel] = "Store" ) )
```
**Why `KEEPFILTERS`:** without it, a matrix row for "Store" would still show the web figure under *Web Purchases*, because `CALCULATE` would overwrite the row filter. `KEEPFILTERS` intersects instead, so the measure is correct in cards *and* tables.
**Expected:** Web 8,435 · Catalog 5,476 · Store 11,876

### Average Web / Catalog / Store Purchases
```dax
Avg Web Purchases     = DIVIDE ( [Web Purchases],     [Total Customers] )
Avg Catalog Purchases = DIVIDE ( [Catalog Purchases], [Total Customers] )
Avg Store Purchases   = DIVIDE ( [Store Purchases],   [Total Customers] )
```
**Expected:** 4.10 · 2.66 · 5.77

### Total Deal Purchases / Average Deal Purchases
```dax
Total Deal Purchases = SUM ( Customer[Deal Purchases] )
Avg Deal Purchases   = DIVIDE ( [Total Deal Purchases], [Total Customers] )
Deal Share of Purchases % =
DIVIDE ( [Total Deal Purchases], CALCULATE ( [Total Channel Purchases], REMOVEFILTERS ( Channel ) ) )
```
**Why it matters:** shows reliance on discounts. Deals sit on the Customer table (customer grain) because a deal is a price attribute, not a channel.
**Expected:** 4,814 · 2.34 · 18.7%

### Channel Share %
```dax
Channel Share % =
DIVIDE ( [Total Channel Purchases], CALCULATE ( [Total Channel Purchases], REMOVEFILTERS ( Channel ) ) )
```
**Measures:** each channel's share of purchase **volume** in the current customer context.
**Why it matters:** this is the defensible "channel contribution" metric. Combined with a segment slicer (e.g. Income Band) it shows which segments lean on which channel.
**Expected:** Store 46.1% · Web 32.7% · Catalog 21.2%

### Channel Non-Users %
```dax
Channel Non-Users % =
VAR NonUsers =
    CALCULATE (
        DISTINCTCOUNT ( 'Channel Purchases'[Customer ID] ),
        'Channel Purchases'[Purchase Count] = 0
    )
RETURN DIVIDE ( NonUsers, [Total Customers] )
```
**Measures:** share of customers who have never bought through the channel in context (use in a visual with Channel on the axis).
**Why it matters:** identifies under-utilised channels. **Expected:** Catalog 26.1% (537 customers), Web 2.2%, Store 0.7%.

---

## 3. Campaign

### Campaign Acceptances
```dax
Campaign Acceptances = SUM ( 'Campaign Response'[Accepted] )
```
**Expected:** 931 across all six campaigns.

### Campaign Acceptance Rate
```dax
Campaign Acceptance Rate =
DIVIDE ( [Campaign Acceptances], COUNTROWS ( 'Campaign Response' ) )
```
**Measures:** acceptances ÷ customer-campaign offers in context. On a bar chart by Campaign it is each campaign's rate; on a card it is the blended rate across campaigns.
**Why it matters:** the primary campaign KPI. Rate (not count) is used because it stays comparable when a slicer shrinks the customer base.
**Expected:** 7.54% overall · Last 15.21% · Cmp4 7.68% · Cmp3 7.34% · Cmp5 7.19% · Cmp1 6.56% · Cmp2 1.26%
**Assumption:** every customer has a flag for every campaign, so all customers are treated as having received every campaign. The dataset does not contain targeting lists.

### Last Campaign Response Rate
```dax
Last Campaign Response Rate =
CALCULATE ( [Campaign Acceptance Rate], Campaign[Is Last Campaign] = 1 )
```
**Expected:** 15.21% — the KPI card on page 1.

### Acceptance Rate vs Average (pp)
```dax
Acceptance Rate vs Average (pp) =
VAR AllCampaigns = CALCULATE ( [Campaign Acceptance Rate], REMOVEFILTERS ( Campaign ) )
RETURN ( [Campaign Acceptance Rate] - AllCampaigns ) * 100
```
**Measures:** percentage-point gap between a campaign (or segment) and the six-campaign average. Use for conditional formatting (green above 0, red below).

### Best Campaign / Worst Campaign
```dax
Best Campaign =
VAR Ranked = ADDCOLUMNS ( VALUES ( Campaign[Campaign] ), "@Rate", [Campaign Acceptance Rate] )
RETURN MAXX ( TOPN ( 1, Ranked, [@Rate], DESC ), Campaign[Campaign] )

Worst Campaign =
VAR Ranked = ADDCOLUMNS ( VALUES ( Campaign[Campaign] ), "@Rate", [Campaign Acceptance Rate] )
RETURN MAXX ( TOPN ( 1, Ranked, [@Rate], ASC ), Campaign[Campaign] )
```
**Why it matters:** text cards answer "which campaign won?" without the reader parsing a chart, and they update with segment slicers.
**Expected:** Best = "Last Campaign (6)", Worst = "Campaign 2".

### Campaign Engagement Rate
```dax
Customers Accepting Any Campaign =
CALCULATE ( [Total Customers], Customer[Accepted Any Campaign] = 1 )

Campaign Engagement Rate = DIVIDE ( [Customers Accepting Any Campaign], [Total Customers] )
```
**Definition:** % of customers who accepted at least one of the six campaigns.
**Expected:** 569 customers · 27.65%

### Prior Acceptor Response Lift
```dax
Prior Acceptor Response Lift =
VAR WithPrior =
    CALCULATE ( [Last Campaign Response Rate], Customer[Prior Campaigns Accepted] >= 1 )
VAR WithoutPrior =
    CALCULATE ( [Last Campaign Response Rate], Customer[Prior Campaigns Accepted] = 0 )
RETURN DIVIDE ( WithPrior, WithoutPrior )
```
**Measures:** how many times more likely a previous acceptor is to accept the last campaign.
**Why it matters:** answers business question A5 in one number and supports a targeting recommendation.
**Expected:** 4.79× (40.60% vs 8.48%)

### Spend of Campaign Acceptors (cross-fact measure)
```dax
Spend of Campaign Acceptors =
VAR Acceptors =
    CALCULATETABLE ( VALUES ( 'Campaign Response'[Customer ID] ), 'Campaign Response'[Accepted] = 1 )
RETURN
    CALCULATE ( [Total Spending], TREATAS ( Acceptors, Customer[Customer ID] ) )

Avg Spend of Campaign Acceptors =
VAR Acceptors =
    CALCULATETABLE ( VALUES ( 'Campaign Response'[Customer ID] ), 'Campaign Response'[Accepted] = 1 )
RETURN
    DIVIDE ( [Spend of Campaign Acceptors], COUNTROWS ( Acceptors ) )
```
**Measures:** the product spend of customers who accepted the campaign(s) currently selected.
**Why it matters / why this pattern:** the model uses single-direction filters, so selecting "Campaign 4" does not filter `Product Spend` on its own. `TREATAS` passes the list of acceptors to `Customer`, which then filters spend. This avoids bi-directional relationships (which cause ambiguity and slower models) while still answering "how valuable are this campaign's responders?".
**Expected (Campaign = Last):** avg 980 vs 539 for non-acceptors.

### Heatmap Font Color (conditional formatting)
```dax
Heatmap Font Color =
IF ( [Campaign Acceptance Rate] >= 0.4, "#FFFFFF", "#252423" )
```
**Used for:** *Format → Cell elements → Font color → fx → Field value* on the campaign × income matrix (page 2).
**Why a measure:** dark-navy heatmap cells need white text to stay readable. Driving the colour from a measure keeps the rule in one readable line of DAX and works for any filter selection.

---

## 4. Product

### Product Spend Share %
```dax
Product Spend Share % =
DIVIDE ( [Total Spending], CALCULATE ( [Total Spending], REMOVEFILTERS ( Product ) ) )
```
**Expected:** Wines 50.1% · Meat 27.7% · Gold 7.2% · Fish 6.2% · Sweets 4.5% · Fruits 4.3%

### Top Product
```dax
Top Product =
VAR Ranked = ADDCOLUMNS ( VALUES ( Product[Product] ), "@Spend", [Total Spending] )
RETURN MAXX ( TOPN ( 1, Ranked, [@Spend], DESC ), Product[Product] )
```
**Expected:** "Wines"

### Product Penetration %
```dax
Product Buyers =
CALCULATE ( DISTINCTCOUNT ( 'Product Spend'[Customer ID] ), 'Product Spend'[Spend Amount] > 0 )

Product Penetration % = DIVIDE ( [Product Buyers], [Total Customers] )
```
**Measures:** share of customers who bought the product at all.
**Why it matters:** separates "big spend from few customers" from "broad but shallow" categories (Meat is bought by 2,057 of 2,058 customers; Sweets by 1,672).

---

## 5. Engagement & Recency

```dax
Average Recency (days) = AVERAGE ( Customer[Recency Days] )

Active Customers (0-30d)   = CALCULATE ( [Total Customers], Customer[Recency Days] <= 30 )
Active Customer Rate %     = DIVIDE ( [Active Customers (0-30d)], [Total Customers] )

Lapsing Customers (61d+)   = CALCULATE ( [Total Customers], Customer[Recency Days] > 60 )

Disengaged Customers =
CALCULATE ( [Total Customers], Customer[Recency Days] > 60, Customer[Accepted Any Campaign] = 0 )
Disengaged Rate % = DIVIDE ( [Disengaged Customers], [Total Customers] )

High-Value Lapsing Customers =
CALCULATE ( [Total Customers], Customer[Spend Quartile] = "Top 25%", Customer[Recency Days] > 60 )

Complaint Rate % = DIVIDE ( CALCULATE ( [Total Customers], Customer[Complained] = 1 ), [Total Customers] )
```
**Definitions** are deliberately simple and stated on the report: *Active* = last purchase ≤ 30 days ago; *Lapsing* = 61+ days; *Disengaged* = lapsing **and** never accepted a campaign.
**Why it matters:** recency is the only behavioural-freshness signal in the data; customers active in the last 30 days respond to the last campaign at 24.3% vs 8.4% for lapsing ones.
**Expected:** avg recency 48.95 · active 667 (32.41%) · lapsing 789 · disengaged 602 (29.25%) · high-value lapsing 202 · complaints 0.97%

### Customer acquisition trend (the only valid time series)
```dax
Customers Enrolled = [Total Customers]          -- use with 'Date'[Year Month] on the axis

Cumulative Customers Enrolled =
CALCULATE ( [Total Customers], FILTER ( ALL ( 'Date'[Date] ), 'Date'[Date] <= MAX ( 'Date'[Date] ) ) )
```
**Why it matters:** shows customer-base growth from Jul 2012 to Jun 2014 via the `Date → Customer` relationship. It is labelled "enrollment" on the report so nobody reads it as a sales trend.

---

## 6. Data Quality

```dax
DQ Exception Rows = COUNTROWS ( 'DQ Exceptions' )

Excluded Duplicate Rows =
CALCULATE ( COUNTROWS ( 'DQ Exceptions' ), 'DQ Exceptions'[Issue Code] = "DQ_DUPLICATE" )

Source Rows =
CALCULATE ( COUNTROWS ( Customer ), REMOVEFILTERS () ) + [Excluded Duplicate Rows]

Customers With DQ Flags = CALCULATE ( [Total Customers], Customer[DQ Issue Count] > 0 )
Customers With DQ Flags % = DIVIDE ( [Customers With DQ Flags], [Total Customers] )

Unverified Country Customers = CALCULATE ( [Total Customers], Customer[Country Conflict Flag] = 1 )

Data Quality Status =
VAR Dupes = [Excluded Duplicate Rows]
RETURN
    IF ( Dupes > 0,
         "⚠ " & FORMAT ( Dupes, "#,0" ) & " suspected duplicate rows excluded",
         "✔ No duplicate rows detected" )

Small Sample Warning =
IF ( [Total Customers] < 30, "⚠ Small sample (n = " & [Total Customers] & ") - interpret with caution" )
```
**Why it matters:** the report states its own reliability. A manager sees *on the page* that 182 rows were excluded and that 131 customers have an unverified country, instead of discovering it later.
**Expected:** DQ exception rows 363 · excluded duplicates 182 · source rows 2,240 · customers with flags 174 (8.5%) · unverified country 131.
`Small Sample Warning` is added to the tooltip of country visuals (Mexico has 2 customers after de-duplication).

### Dynamic title (example)
```dax
Title Campaign Page =
"Campaign acceptance — "
    & SELECTEDVALUE ( Customer[Country], "all countries" )
    & " · " & FORMAT ( [Total Customers], "#,0" ) & " customers"
```
Used via *Format → Title → fx* so screenshots always state their filter context.
