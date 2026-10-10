// =====================================================================
// Query: DQ Exceptions   (source: vw_dq_exceptions, 363 rows)
// Contains ALL source rows with an issue, INCLUDING the 182 excluded
// duplicates. Deliberately NOT related to Customer: a relationship
// would create a blank Customer row for the excluded IDs.
// =====================================================================
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".vw_dq_exceptions"),
    Renamed = Table.RenameColumns(Data, {{"customer_id", "Customer ID"}, {"issue_code", "Issue Code"},
                {"issue_description", "Issue"}, {"severity", "Severity"}, {"handling", "Handling"},
                {"include_in_reporting", "In Reporting Flag"}, {"detail", "Detail"}}),
    Typed   = Table.TransformColumnTypes(Renamed, {{"Customer ID", Int64.Type}, {"Issue Code", type text},
                {"Issue", type text}, {"Severity", type text}, {"Handling", type text},
                {"In Reporting Flag", Int64.Type}, {"Detail", type text}}),
    AddInReporting  = Table.AddColumn(Typed, "In Reporting Set",
                each if [In Reporting Flag] = 1 then "Included" else "Excluded", type text),
    AddSeveritySort = Table.AddColumn(AddInReporting, "Severity Order",
                each if [Severity] = "High" then 1 else if [Severity] = "Medium" then 2 else 3, Int64.Type)
in
    AddSeveritySort
