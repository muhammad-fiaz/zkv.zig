---
title: Export JSONL
description: Export database to JSONL format for interoperability with zkv.zig.
---

# Export JSONL

Export your database to [JSON Lines](https://jsonlines.org/) format for interoperability with other tools and languages.

## Usage

```zig
const json = try db.exportData(.jsonl);
defer std.heap.page_allocator.free(json);
std.debug.print("{s}\n", .{json});
```

## Output Format

Each line is a JSON object with `key` and `value` fields:

```json
{"key":"users:1:name","value":"Alice"}
{"key":"users:1:email","value":"alice@example.com"}
{"key":"users:2:name","value":"Bob"}
{"key":"configs:theme","value":"dark"}
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
        .path = "examples/jsonl_export.zkv",
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
    const json = try db.exportData(.jsonl);
    defer std.heap.page_allocator.free(json);

    std.debug.print("JSONL export:\n{s}\n", .{json});
}
```

## When to Use

- Pipe data to `jq` for analysis
- Import into Elasticsearch, PostgreSQL, or other databases
- Debug database contents in a human-readable format
