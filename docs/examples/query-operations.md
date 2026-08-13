# Query Operations

Search by prefix, filter with predicates, sort entries, and iterate over ranges.

> [!TIP]
> Use `prefix()` for efficient iteration over key patterns, and `filter()` for custom predicate based searches.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/query_operations.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    const posts = db.collection("posts");

    try users.set("1:name", "Alice");
    try users.set("1:role", "admin");
    try users.set("2:name", "Bob");
    try users.set("2:role", "editor");
    try posts.set("1:title", "Hello");

    // Search by prefix
    var results = try db.search(.{ .prefix = "users:" });
    defer results.deinit(allocator);

    // Filter: find admins
    var admins = try db.filter(null, struct {
        fn is_admin(_: void, e: zkv.Entry) bool {
            return std.mem.eql(u8, e.value, "admin");
        }
    }.is_admin, .{});
    defer admins.deinit(allocator);

    // Iterator
    var iter = users.iterator(null, null);
    while (iter.next()) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }

    // Range query
    var range_result = users.range("1:", "3:");
    defer range_result.deinit(allocator);

    // Count
    std.debug.print("Users: {}\n", .{users.count()});
    std.debug.print("Posts: {}\n", .{posts.count()});
}
```
