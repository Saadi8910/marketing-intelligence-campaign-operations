// =====================================================================
// Query: Product Spend   (source: vw_fact_product_spend)
// One row per customer per product (2,058 x 6 = 12,348). Unpivoted in SQL.
// Power Query step: data types and friendly names only.
// =====================================================================
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".vw_fact_product_spend"),
    Renamed = Table.RenameColumns(Data, {{"customer_id", "Customer ID"}, {"product_key", "Product Key"}, {"spend_amount", "Spend Amount"}}),
    Typed   = Table.TransformColumnTypes(Renamed, {{"Customer ID", Int64.Type}, {"Product Key", Int64.Type}, {"Spend Amount", Int64.Type}})
in
    Typed
