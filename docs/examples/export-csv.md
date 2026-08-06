---
title: Export CSV
description: Export database to CSV format for spreadsheets and data analysis with zkv.zig.
---

# Export CSV

Export your database to CSV format for use in spreadsheets, data analysis tools, and other applications.

## Usage

```zig
const csv = try db.exportData(.csv);
defer std.heap.page_allocator.free(csv);
std.debug.print("{s}\n", .{csv});
```

## Output Format

Standard CSV with `key,value` header:

```csv
key,value
"users:1:name","Alice"
"users:1:email","alice@example.com"
"users:2:name","Bob"
"configs:theme","dark"
```

## Full Example

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/csv_export.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    const configs = db.collection("configs");

    try users.set("1:name", "Alice");
    try users.set("1:email", "alice@example.com");
    try users.set("2:name", "Bob");
    try configs.set("theme", "dark");
    try configs.set("lang", "en");

    // Export to string.
    const csv = try db.exportData(.csv);
    defer std.heap.page_allocator.free(csv);

    std.debug.print("CSV export:\n{s}\n", .{csv});
}
```

## When to Use

- Open in Excel, Google Sheets, or LibreOffice Calc
- Import into SQL databases
- Share data with non-technical users
