const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/queries.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    const posts = db.collection("posts");

    std.debug.print("=== Populating User Directory ===\n", .{});
    try users.set("1:name", "Alice");
    try users.set("1:role", "admin");
    try users.set("1:dept", "engineering");
    try users.set("2:name", "Bob");
    try users.set("2:role", "editor");
    try users.set("2:dept", "marketing");
    try users.set("3:name", "Charlie");
    try users.set("3:role", "viewer");
    try users.set("3:dept", "engineering");
    try users.set("4:name", "Diana");
    try users.set("4:role", "admin");
    try users.set("4:dept", "marketing");
    try posts.set("1:title", "Hello World");
    try posts.set("1:author", "Alice");
    try posts.set("2:title", "Zig is Great");
    try posts.set("2:author", "Bob");
    std.debug.print("Users: {}, Posts: {}\n", .{ users.count(), posts.count() });

    std.debug.print("\n=== Search: All Users ===\n", .{});
    var user_entries = users.entries();
    defer user_entries.deinit(allocator);
    for (user_entries.items) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }

    std.debug.print("\n=== Filter: Find Admins ===\n", .{});
    var admin_results = try db.search(.{ .prefix = "users:1:" });
    defer admin_results.deinit(allocator);
    for (admin_results.items) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }

    std.debug.print("\n=== Iterator: All Posts ===\n", .{});
    var iter = posts.iterator(null, null);
    while (iter.next()) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }

    std.debug.print("\n=== Range: Users 1..3 ===\n", .{});
    var r = users.range("1:name", "3:name");
    defer r.deinit(allocator);
    for (r.items) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }

    std.debug.print("\n=== Count ===\n", .{});
    std.debug.print("Users: {}\n", .{users.count()});
    std.debug.print("Posts: {}\n", .{posts.count()});
}
