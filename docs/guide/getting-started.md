---
title: Getting Started
description: Quick introduction to zkv.zig - a fast, embedded key-value database for Zig.
---

# Getting Started

zkv.zig is a lightweight, embedded key-value database for Zig. It supports TTL, transactions, batch operations, queries, compression, and multiple export formats — all in a single file.

## Basic Usage

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    // Open the database
    var db = try zkv.Database.open(allocator, .{ .path = "my_data.zkv" });
    defer db.close();

    // Get a collection
    const users = db.collection("users");

    // Create
    try users.set("1:name", "Alice");
    try users.set("1:age", "30");

    // Read
    if (users.get("1:name")) |name| {
        std.debug.print("Name: {s}\n", .{name});
    }

    // Update
    try users.set("1:age", "31");

    // Delete
    try users.delete("1:age");

    // Empty values are valid
    try users.set("1:bio", "");
    std.debug.print("Bio exists: {}\n", .{users.exists("1:bio")});

    // Count entries
    std.debug.print("Total: {}\n", .{users.count()});
}
```

## Key Concepts

- **Collection-First**: All CRUD goes through `db.collection("name")`
- **Key/Value**: Both are `[]const u8` — raw byte slices.
- **No schema**: Store any bytes; no type constraints.
- **Empty Values**: Zero-length values are distinct from missing keys.
- **ACID transactions**: Atomic reads and writes.
- **TTL**: Auto-expiring keys with millisecond precision.
- **Compression**: Automatic zstd, brotli, gzip on all writes; lzma, xz decompress supported.

## Next Steps

- [Installation](/guide/installation) — Add zkv to your project
- [CRUD Operations](/guide/crud) — Put, get, delete, and more
- [Transactions](/guide/transactions) — Atomic multi-key operations
- [Batch Operations](/guide/batch) — Bulk writes with collections
- [Compression](/api/options) — Configure compression algorithms
