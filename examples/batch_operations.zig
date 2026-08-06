const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/batch_ops.zkv",
    });
    defer db.close();

    const products = db.collection("products");
    const users = db.collection("users");

    // Pre-populate some data
    try products.set("widget:name", "Super Widget");
    try products.set("widget:price", "29.99");
    try products.set("gadget:name", "Mega Gadget");
    try products.set("gadget:price", "49.99");
    try users.set("1:name", "Alice");

    std.debug.print("=== Batch Set ===\n", .{});
    {
        var batch = db.batch();
        defer batch.deinit();

        try batch.set(products, "widget:price", "34.99");
        try batch.set(products, "gadget:price", "54.99");
        try batch.set(products, "doohickey:name", "Cool Doohickey");
        try batch.set(products, "doohickey:price", "22.99");
        try batch.set(users, "2:name", "Bob");
        try batch.set(users, "3:name", "Charlie");
        try batch.commit();
    }
    std.debug.print("Products: {}\n", .{products.count()});
    std.debug.print("Users: {}\n", .{users.count()});

    std.debug.print("\n=== Batch Delete ===\n", .{});
    {
        var batch = db.batch();
        defer batch.deinit();

        try batch.delete(products, "doohickey:name");
        try batch.delete(products, "doohickey:price");
        try batch.delete(users, "3:name");
        try batch.commit();
    }
    std.debug.print("Products after delete: {}\n", .{products.count()});
    std.debug.print("Users after delete: {}\n", .{users.count()});

    std.debug.print("\n=== Batch Clear ===\n", .{});
    {
        var batch = db.batch();
        defer batch.deinit();

        try batch.clear(users);
        try batch.commit();
    }
    std.debug.print("Users after clear: {}\n", .{users.count()});
    std.debug.print("Products unchanged: {}\n", .{products.count()});

    std.debug.print("\n=== Batch Rollback ===\n", .{});
    {
        var batch = db.batch();
        try batch.set(products, "temp:key", "temp:val");
        batch.rollback();
    }
    std.debug.print("After rollback, temp:key exists: {}\n", .{products.get("temp:key") != null});

    std.debug.print("\n=== Final State ===\n", .{});
    var iter = products.iterator(null, null);
    while (iter.next()) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }
}
