// =====================================================================
// Query: Date   (generated entirely in Power Query)
// The ONLY date in the source is the customer enrollment date, so this
// calendar covers the enrollment window and is used for the customer
// acquisition trend. It is NOT a transaction calendar: the dataset has
// no purchase dates, so time-intelligence on spend is not possible.
// After loading: Table tools > Mark as date table > Date.
// =====================================================================
let
    MinDate   = List.Min(Customer[Enrollment Date]),
    MaxDate   = List.Max(Customer[Enrollment Date]),
    StartDate = Date.StartOfMonth(MinDate),            // 2012-07-01
    EndDate   = Date.EndOfMonth(MaxDate),              // 2014-06-30
    DayCount  = Duration.Days(EndDate - StartDate) + 1,
    Dates     = List.Dates(StartDate, DayCount, #duration(1, 0, 0, 0)),
    AsTable   = Table.FromList(Dates, Splitter.SplitByNothing(), {"Date"}),
    Typed     = Table.TransformColumnTypes(AsTable, {{"Date", type date}}),
    AddYear   = Table.AddColumn(Typed,   "Year",         each Date.Year([Date]),        Int64.Type),
    AddQtr    = Table.AddColumn(AddYear, "Quarter",      each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddMonthN = Table.AddColumn(AddQtr,  "Month Number", each Date.Month([Date]),       Int64.Type),
    AddMonth  = Table.AddColumn(AddMonthN, "Month",      each Date.ToText([Date], "MMM"), type text),
    AddYM     = Table.AddColumn(AddMonth, "Year Month",  each Date.ToText([Date], "yyyy-MM"), type text),
    AddYMSort = Table.AddColumn(AddYM,   "Year Month Sort", each Date.Year([Date]) * 100 + Date.Month([Date]), Int64.Type)
in
    AddYMSort
