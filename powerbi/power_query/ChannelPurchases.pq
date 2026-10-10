// =====================================================================
// Query: Channel Purchases   (source: vw_fact_channel_purchases)
// One row per customer per channel (2,058 x 3 = 6,174). Deals excluded on purpose.
// Power Query step: data types and friendly names only.
// =====================================================================
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".vw_fact_channel_purchases"),
    Renamed = Table.RenameColumns(Data, {{"customer_id", "Customer ID"}, {"channel_key", "Channel Key"}, {"purchase_count", "Purchase Count"}}),
    Typed   = Table.TransformColumnTypes(Renamed, {{"Customer ID", Int64.Type}, {"Channel Key", Int64.Type}, {"Purchase Count", Int64.Type}})
in
    Typed
