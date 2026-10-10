// Query: Campaign   (source: dim_campaign, 6 rows)
// After loading: sort 'Campaign'[Campaign] by 'Campaign'[Campaign Sequence].
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".dim_campaign"),
    Renamed = Table.RenameColumns(Data, {{"campaign_key", "Campaign Key"}, {"campaign_name", "Campaign"},
                {"campaign_short", "Campaign Short"}, {"campaign_sequence", "Campaign Sequence"},
                {"is_last_campaign", "Is Last Campaign"}, {"source_column", "Source Column"}}),
    Typed   = Table.TransformColumnTypes(Renamed, {{"Campaign Key", Int64.Type}, {"Campaign", type text},
                {"Campaign Short", type text}, {"Campaign Sequence", Int64.Type},
                {"Is Last Campaign", Int64.Type}, {"Source Column", type text}})
in
    Typed
