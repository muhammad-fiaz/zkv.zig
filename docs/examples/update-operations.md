---
title: Update Operations
description: Update specific keys, batch updates, transactions, and delete.
---

# Update Operations

Update specific keys, batch replace values, and conditional updates.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/update_operations.zkv",
    });
    defer db.close();

    const users = db.collection("users");

    // Update specific key (set overwrites)
    try users.set("1:age", "30");
    try users.set("1:age", "31");
    try users.set("1:city", "Boston");

    // Batch update
    var batch = db.batch();
    defer batch.deinit();
    try batch.set(users, "2:role", "viewer");
    try batch.set(users, "3:role", "viewer");
    try batch.commit();

    // Transaction counter
    var txn = try db.transaction();
    try txn.put("counter", "1");
    try db.commitTransaction(&txn);

    // Delete specific key
    try users.delete("1:email");

    // Clear collection
    var temp = db.collection("temp");
    try temp.set("a", "1");
    try temp.set("b", "2");
    _ = try temp.clear();
}
```