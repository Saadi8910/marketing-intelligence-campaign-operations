# n8n — Marketing KPI Monitoring & Data Quality Alert

> **This workflow demonstrates how BI monitoring could be automated. It is not connected to a live company production environment.** It runs against the local `marketing_intelligence` MySQL database built by this project.

## What problem it solves
A dashboard only helps if someone opens it. Data problems (a re-loaded file full of duplicates, blank campaign flags) or a KPI falling below target should reach the owner **before** a manager presents wrong numbers. This workflow checks the database on a schedule and raises one consolidated message when something needs attention.

## Flow

```
Daily 08:00 Schedule
        │
        ▼
Run Monitoring Checks  (MySQL: SELECT ... FROM vw_monitoring_checks)  → 9 rows, one per check
        │
        ├──► Log Check Results  (MySQL insert → monitoring_log)          every run, every check
        │
        └──► Any Alerts?  (IF status = "ALERT")
                 ├─ true  ► Build Alert Message (Code: 1 message for all alerts)
                 │              ► Send Notification (placeholder)
                 └─ false ► No Alert - All Checks OK
```

## Design decisions
- **Business logic lives in SQL, not in n8n.** The workflow only runs one query and routes the result. The checks (`vw_monitoring_checks`) and their limits (`monitoring_thresholds`) are in `sql/06_kpi_queries.sql`, so they are version-controlled, testable in MySQL and reusable by Power BI.
- **Thresholds are data, not code.** Changing the response-rate target is an `UPDATE monitoring_thresholds ...`, not a workflow edit.
- **One message per run**, not one per failed check, to avoid alert fatigue.
- **Every run is logged** (OK and ALERT) in `monitoring_log`, which gives a history of data health over time.
- **Least privilege:** the n8n database user needs only `SELECT` on the schema and `INSERT` on `monitoring_log` (see bottom of `06_kpi_queries.sql`).

## The checks

| Check | Category | Alert when | Current value | Status |
|---|---|---|---|---|
| suspected_duplicate_rows | Data quality | > 0 | 182 | ALERT |
| invalid_birth_year_rows | Data quality | > 0 | 3 | ALERT |
| missing_income_pct | Data quality | > 2% | 1.07% | OK |
| missing_campaign_flag_rows | Data quality | > 0 | 0 | OK |
| invalid_campaign_flag_rows | Data quality | > 0 | 0 | OK |
| raw_vs_staging_row_difference | Data quality | > 0 | 0 | OK |
| last_campaign_response_rate_pct | KPI | < 10% | 15.21% | OK |
| lowest_campaign_acceptance_pct | KPI | < 2% | 1.26% | ALERT |
| catalog_purchase_share_pct | KPI | < 15% | 21.24% | OK |

Thresholds are illustrative values chosen for this portfolio, not business targets from a real company. Because the dataset is static, the same three alerts fire on every run; the point is the mechanism, which would catch *changes* when connected to a refreshed source.

## How to import and run

1. **Prerequisite:** run `sql/01`–`06` so `vw_monitoring_checks` and `monitoring_log` exist.
2. In n8n: **Workflows → Import from File → `n8n/workflow.json`**.
3. **Credentials** are intentionally not included in the file. Open *Run Monitoring Checks*, choose **Credential → Create new → MySQL**, and enter host, database `marketing_intelligence`, user and password. Select the same credential in *Log Check Results*.
   - n8n in Docker reaching MySQL on your machine: use host `host.docker.internal`, not `localhost`.
4. **Test without a database:** *Run Monitoring Checks* has **pinned data** (the real 9-row output of the view). Click *Test workflow* — the IF node routes 3 ALERT and 6 OK items and *Build Alert Message* produces the message. Disable *Log Check Results* for this test, as it still needs a live database.
5. **Test live:** unpin the data on *Run Monitoring Checks* and run again. Confirm in MySQL:
   ```sql
   SELECT run_at, check_name, metric_value, status FROM monitoring_log ORDER BY log_id DESC LIMIT 9;
   ```
6. **Activate** the workflow to run it on the schedule.

If a node shows a parameter warning after import (n8n node versions change between releases), open it and re-select the option shown in the flow above: e.g. in *Log Check Results* pick table `monitoring_log` and *Map Automatically*.

## Connecting a real notification
*Send Notification (placeholder)* is a No-Op node because no email/Slack credentials are committed. To make it real, replace it with one of:
- **Gmail / Microsoft Outlook / Send Email** node — Subject `{{ $json.subject }}`, Body `{{ $json.body }}`
- **Slack** node — Text `{{ $json.subject }}\n{{ $json.body }}`

## Example alert output
Produced by *Build Alert Message* from the pinned data:
```
Marketing BI monitoring: 3 check(s) need attention
Marketing Intelligence & Campaign Operations - automated KPI / data-quality check
Run time (UTC): <timestamp>

- [Data quality] invalid_birth_year_rows: 3 (alert if > 0)
- [KPI] lowest_campaign_acceptance_pct: 1.26 (alert if < 2)
- [Data quality] suspected_duplicate_rows: 182 (alert if > 0)

Source: marketing_intelligence.vw_monitoring_checks (MySQL).
Portfolio demonstration - not connected to a live production environment.
```

## Screenshots
Add after importing: `n8n/screenshots/workflow_canvas.png` (the canvas) and `n8n/screenshots/alert_output.png` (output of *Build Alert Message*).
