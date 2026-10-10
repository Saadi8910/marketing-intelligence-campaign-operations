// =====================================================================
// Query: Campaign Response   (source: vw_fact_campaign_response)
// One row per customer per campaign (2,058 x 6 = 12,348). Unpivoted in SQL.
// Power Query step: data types and friendly names only.
// =====================================================================
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".vw_fact_campaign_response"),
    Renamed = Table.RenameColumns(Data, {{"customer_id", "Customer ID"}, {"campaign_key", "Campaign Key"}, {"accepted", "Accepted"}}),
    Typed   = Table.TransformColumnTypes(Renamed, {{"Customer ID", Int64.Type}, {"Campaign Key", Int64.Type}, {"Accepted", Int64.Type}})
in
    Typed
