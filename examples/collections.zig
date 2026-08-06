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

    std.debug.print("=== Scenario 1: Named Collections ===\n", .{});
    const users = db.collection("users");
    const posts = db.collection("posts");
    const products = db.collection("products");

    try users.set("1", "Alice");
    try users.set("2", "Bob");
    try users.set("3", "Charlie");
    std.debug.print("Users: {} entries\n", .{users.count()});

    try posts.set("1", "Hello World");
    try posts.set("2", "Zig is Great");
    std.debug.print("Posts: {} entries\n", .{posts.count()});

    try products.set("widget", "29.99");
    try products.set("gadget", "49.99");
    std.debug.print("Products: {} entries\n", .{products.count()});

    std.debug.print("\n=== Scenario 2: Get from Collection ===\n", .{});
    if (users.get("1")) |name| std.debug.print("User 1: {s}\n", .{name});
    if (posts.get("2")) |title| std.debug.print("Post 2: {s}\n", .{title});

    std.debug.print("\n=== Scenario 3: Collection Entries ===\n", .{});
    var user_entries = users.entries();
    defer user_entries.deinit(allocator);
    for (user_entries.items) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }

    std.debug.print("\n=== Scenario 4: Collection Keys & Values ===\n", .{});
    var product_keys = products.keys();
    defer product_keys.deinit(allocator);
    std.debug.print("Product keys: ", .{});
    for (product_keys.items) |key| std.debug.print("{s} ", .{key});
    std.debug.print("\n", .{});

    var product_values = products.values();
    defer product_values.deinit(allocator);
    std.debug.print("Product values: ", .{});
    for (product_values.items) |val| std.debug.print("{s} ", .{val});
    std.debug.print("\n", .{});

    std.debug.print("\n=== Scenario 5: Delete from Collection ===\n", .{});
    std.debug.print("Before: {} users\n", .{users.count()});
    try users.delete("3");
    std.debug.print("After:  {} users\n", .{users.count()});

    std.debug.print("\n=== Scenario 6: Clear Collection ===\n", .{});
    std.debug.print("Before: {} posts\n", .{posts.count()});
    _ = try posts.clear();
    std.debug.print("After:  {} posts\n", .{posts.count()});

    std.debug.print("\n=== Scenario 7: Contains ===\n", .{});
    std.debug.print("users contains '1': {}\n", .{users.exists("1")});
    std.debug.print("users contains '99': {}\n", .{users.exists("99")});
}
