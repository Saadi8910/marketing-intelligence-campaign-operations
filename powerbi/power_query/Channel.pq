// Query: Channel   (source: dim_channel, 3 rows: Web, Catalog, Store)
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".dim_channel"),
    Renamed = Table.RenameColumns(Data, {{"channel_key", "Channel Key"}, {"channel_name", "Channel"}, {"source_column", "Source Column"}}),
    Typed   = Table.TransformColumnTypes(Renamed, {{"Channel Key", Int64.Type}, {"Channel", type text}, {"Source Column", type text}})
in
    Typed
