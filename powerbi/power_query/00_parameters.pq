// =====================================================================
// Parameters  (Home > Manage Parameters > New Parameter)
// This build connects to MySQL through ODBC (Odbc.Query), using a DSN
// configured in Windows "ODBC Data Sources (64-bit)".
// Create these TEXT parameters. Nothing secret is stored here: the
// MySQL login lives in the DSN / Power BI credential store and is never
// saved in the query text or in Git.
// =====================================================================
// Name: OdbcDsn    Type: Text   Current value: <your DSN name>
// Name: DbName     Type: Text   Current value: marketing_intelligence
// Name: DbServer   Type: Text   Current value: localhost
//       (only needed for the native-connector alternative below)
//
// NATIVE MYSQL CONNECTOR ALTERNATIVE
// (requires MySQL Connector/NET installed). In each query, replace the
// Data step with:
//   Source = MySQL.Database(DbServer, DbName, [ReturnSingleDatabase = true]),
//   Data   = Source{[Schema = DbName, Item = "<view name>"]}[Data],
//
// CSV FALLBACK (for reviewers without MySQL): replace the Data step with
//   Source = Csv.Document(File.Contents(CsvFolder & "dim_customer.csv"),
//                         [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
//   Data   = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
// and add a Text parameter CsvFolder = "...\data\processed\"
//
// Why ODBC here: the native connector needs the Connector/NET library;
// an ODBC driver was already installed. Trade-off: a hand-written
// native query prevents query folding of later steps - irrelevant at
// this data size, but the native connector is preferred for large tables.
