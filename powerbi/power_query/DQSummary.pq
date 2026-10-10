// Query: DQ Summary   (source: vw_dq_summary, one row per DQ rule, 9 rows)
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".vw_dq_summary"),
    Renamed = Table.RenameColumns(Data, {{"issue_code", "Issue Code"}, {"issue_description", "Issue"},
                {"severity", "Severity"}, {"handling", "Handling"}, {"affected_rows", "Affected Rows"},
                {"pct_of_source_rows", "Pct Of Source Rows"}}),
    Typed   = Table.TransformColumnTypes(Renamed, {{"Issue Code", type text}, {"Issue", type text},
                {"Severity", type text}, {"Handling", type text}, {"Affected Rows", Int64.Type},
                {"Pct Of Source Rows", type number}}),
    AsPct   = Table.TransformColumns(Typed, {{"Pct Of Source Rows", each _ / 100, Percentage.Type}})
in
    AsPct
