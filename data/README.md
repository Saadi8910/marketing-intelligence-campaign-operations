# Data

## Source
**Maven Analytics — Marketing Campaign Results** (Data Playground)
https://mavenanalytics.io/data-playground/marketing-campaign-results

Public sample dataset of ~2,240 customers of a fictional/anonymised retail business. It is **not** data from any employer or live production system. Check the licence/terms shown on the Maven Analytics page before redistributing; if in doubt, remove `raw/marketing_data.csv` from the repository and ask reviewers to download it from the link above.

## Folders

| Folder | Contents | Produced by |
|---|---|---|
| `raw/` | `marketing_data.csv` (2,240 rows × 28 columns) and `marketing_data_dictionary.csv`, unchanged from the download | Maven Analytics |
| `processed/` | CSV exports of the analytical views (the tables Power BI uses) | `sql/04_clean_marketing_data.sql` |

`processed/` exists only as a **fallback** so reviewers without MySQL can still open the model in Power BI. The intended source for Power BI is the MySQL views.

| Processed file | Rows | Source view/table |
|---|---|---|
| dim_customer.csv | 2,058 | vw_dim_customer |
| fact_campaign_response.csv | 12,348 | vw_fact_campaign_response |
| fact_product_spend.csv | 12,348 | vw_fact_product_spend |
| fact_channel_purchases.csv | 6,174 | vw_fact_channel_purchases |
| dim_campaign.csv / dim_product.csv / dim_channel.csv | 6 / 6 / 3 | reference tables |
| dq_exceptions.csv | 363 | vw_dq_exceptions |
| dq_summary.csv | 9 | vw_dq_summary |

## File-format notes
UTF-8 with BOM, Windows (CRLF) line endings, and a header ` Income ` with surrounding spaces. All three are handled in `sql/02_create_raw_table.sql`.

## Privacy
The data contains no names, emails, addresses or other direct identifiers. No personal data, credentials or connection strings are stored anywhere in this repository.
