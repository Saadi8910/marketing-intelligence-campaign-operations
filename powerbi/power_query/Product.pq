// Query: Product   (source: dim_product, 6 rows)
let
    Data    = Odbc.Query("dsn=" & OdbcDsn, "SELECT * FROM " & DbName & ".dim_product"),
    Renamed = Table.RenameColumns(Data, {{"product_key", "Product Key"}, {"product_name", "Product"}, {"source_column", "Source Column"}}),
    Typed   = Table.TransformColumnTypes(Renamed, {{"Product Key", Int64.Type}, {"Product", type text}, {"Source Column", type text}})
in
    Typed
