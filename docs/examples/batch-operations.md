# Batch Operations

Efficiently insert and remove multiple entries at once using collection aware batch operations.

> [!IMPORTANT]
> Batch operations are not atomic. If you need atomicity across multiple operations, use transactions instead.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/batch_operations.zkv",
    });
    defer db.close();

    const products = db.collection("products");
    const users = db.collection("users");

    // Batch set
    var batch = db.batch();
    defer batch.deinit();

    try batch.set(products, "widget:name", "Super Widget");
    try batch.set(products, "widget:price", "29.99");
    try batch.set(products, "gadget:name", "Mega Gadget");
    try batch.set(products, "gadget:price", "49.99");
    try batch.set(users, "1:name", "Alice");
    try batch.commit();

    // Batch delete
    var batch2 = db.batch();
    defer batch2.deinit();
    try batch2.delete(products, "widget:name");
    try batch2.delete(products, "widget:price");
    try batch2.commit();

    // Batch clear
    var batch3 = db.batch();
    defer batch3.deinit();
    try batch3.clear(users);
    try batch3.commit();

    // Batch rollback
    var batch4 = db.batch();
    try batch4.set(users, "temp:key", "value");
    batch4.rollback(); // discard, nothing committed
}
```
