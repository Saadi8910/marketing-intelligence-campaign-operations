// =====================================================================
// Query: Customer   (source: vw_dim_customer, 2,058 rows)
// SQL already did the heavy lifting (typing, dedup, banding, DQ flags).
// Power Query does presentation-layer shaping only:
//   1. explicit data types (never rely on auto-detect)
//   2. friendly column names for report authors
//   3. Yes/No text versions of 0/1 flags so slicers read naturally
//   4. "Country Status" label so geographic visuals can show the caveat
// =====================================================================
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".vw_dim_customer"),

    Renamed = Table.RenameColumns(Data, {
        {"customer_id", "Customer ID"}, {"year_birth", "Birth Year"}, {"age", "Age"},
        {"age_group", "Age Group"}, {"education", "Education"}, {"education_order", "Education Order"},
        {"marital_status", "Marital Status"}, {"relationship_status", "Relationship Status"},
        {"income", "Income"}, {"income_band", "Income Band"}, {"income_band_order", "Income Band Order"},
        {"kidhome", "Kids At Home"}, {"teenhome", "Teens At Home"},
        {"children_at_home", "Children At Home"}, {"has_children", "Has Children"},
        {"country", "Country"}, {"dq_country_conflict", "Country Conflict Flag"},
        {"enrollment_date", "Enrollment Date"}, {"tenure_days", "Tenure Days"},
        {"recency_days", "Recency Days"}, {"recency_band", "Recency Band"},
        {"recency_band_order", "Recency Band Order"}, {"complain", "Complained"},
        {"total_spend", "Total Spend"}, {"total_purchases", "Total Purchases"},
        {"num_deals_purchases", "Deal Purchases"}, {"num_web_visits_month", "Web Visits Last Month"},
        {"avg_spend_per_purchase", "Avg Spend Per Purchase"}, {"preferred_channel", "Preferred Channel"},
        {"prior_campaigns_accepted", "Prior Campaigns Accepted"},
        {"total_campaigns_accepted", "Campaigns Accepted"},
        {"accepted_any_campaign", "Accepted Any Campaign"},
        {"response_last_campaign", "Responded Last Campaign"},
        {"prior_acceptor_segment", "Prior Acceptor Segment"},
        {"spend_quartile", "Spend Quartile"}, {"spend_quartile_order", "Spend Quartile Order"},
        {"dq_issue_count", "DQ Issue Count"}}),

    Typed = Table.TransformColumnTypes(Renamed, {
        {"Customer ID", Int64.Type}, {"Birth Year", Int64.Type}, {"Age", Int64.Type},
        {"Age Group", type text}, {"Education", type text}, {"Education Order", Int64.Type},
        {"Marital Status", type text}, {"Relationship Status", type text},
        {"Income", Currency.Type}, {"Income Band", type text}, {"Income Band Order", Int64.Type},
        {"Kids At Home", Int64.Type}, {"Teens At Home", Int64.Type},
        {"Children At Home", Int64.Type}, {"Has Children", type text},
        {"Country", type text}, {"Country Conflict Flag", Int64.Type},
        {"Enrollment Date", type date}, {"Tenure Days", Int64.Type},
        {"Recency Days", Int64.Type}, {"Recency Band", type text}, {"Recency Band Order", Int64.Type},
        {"Complained", Int64.Type}, {"Total Spend", Int64.Type}, {"Total Purchases", Int64.Type},
        {"Deal Purchases", Int64.Type}, {"Web Visits Last Month", Int64.Type},
        {"Avg Spend Per Purchase", type number}, {"Preferred Channel", type text},
        {"Prior Campaigns Accepted", Int64.Type}, {"Campaigns Accepted", Int64.Type},
        {"Accepted Any Campaign", Int64.Type}, {"Responded Last Campaign", Int64.Type},
        {"Prior Acceptor Segment", type text}, {"Spend Quartile", type text},
        {"Spend Quartile Order", Int64.Type}, {"DQ Issue Count", Int64.Type}}),

    // Slicer-friendly labels (presentation logic belongs here, not in SQL)
    AddResponder = Table.AddColumn(Typed, "Campaign Responder",
        each if [Accepted Any Campaign] = 1 then "Responder" else "Non-responder", type text),
    AddLastResp = Table.AddColumn(AddResponder, "Last Campaign Response",
        each if [Responded Last Campaign] = 1 then "Accepted" else "Did not accept", type text),
    AddCountryStatus = Table.AddColumn(AddLastResp, "Country Status",
        each if [Country Conflict Flag] = 1 then "Unverified (conflicting duplicates)" else "Verified", type text),
    AddComplaint = Table.AddColumn(AddCountryStatus, "Complaint Status",
        each if [Complained] = 1 then "Complained" else "No complaint", type text)
in
    AddComplaint
