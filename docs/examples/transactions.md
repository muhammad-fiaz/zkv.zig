# Transactions

ACID transactions with commit, rollback, auto commit (`update`), and auto rollback (`view`).

> [!TIP]
> Use `view()` for read only transactions that automatically rollback, and `update()` for write transactions that automatically commit.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/transactions.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    try users.set("1:name", "Alice");
    try users.set("1:balance", "1000");
    try users.set("2:name", "Bob");
    try users.set("2:balance", "500");

    // Commit: atomic transfer
    var txn = try db.transaction();
    try txn.put("users:1:balance", "900");
    try txn.put("users:2:balance", "600");
    try db.commitTransaction(&txn);

    // Rollback: discard changes
    var txn2 = try db.transaction();
    try txn2.put("users:1:balance", "0");
    try db.rollbackTransaction(&txn2);

    // view(): auto-rollback read
    // update(): auto-commit write
}
```
