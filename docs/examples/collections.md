---
title: Collections
description: Named collections, isolation, entries, keys, values, and clear.
---

# Collections

Named collections provide namespace isolation for your data.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/collections.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    const posts = db.collection("posts");

    try users.set("1:name", "Alice");
    try users.set("2:name", "Bob");
    try posts.set("1:title", "Hello");

    // Collection isolation
    std.debug.print("Users: {}, Posts: {}\n", .{ users.count(), posts.count() });

    // Entries
    var entries = users.entries();
    defer entries.deinit(allocator);

    // Keys and values
    var keys = users.keys();
    defer keys.deinit(allocator);

    // Contains
    std.debug.print("users contains '1': {}\n", .{users.exists("1")});

    // Clear
    _ = try posts.clear();
}
```