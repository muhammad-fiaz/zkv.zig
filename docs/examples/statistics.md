# Statistics

Monitor database performance with built in stats tracking.

> [!NOTE]
> Call `resetStats()` to zero out counters. Stats are tracked from the time the database is opened.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/statistics.zkv",
    });
    defer db.close();

    const users = db.collection("users");

    // Perform operations
    try users.set("1:name", "Alice");
    _ = users.get("1:name");
    _ = users.get("missing");
    try users.delete("1:name");

    // Read stats
    var stats = db.getStats();
    std.debug.print("Reads:   {}\n", .{stats.reads});
    std.debug.print("Writes:  {}\n", .{stats.writes});
    std.debug.print("Hits:    {}\n", .{stats.hits});
    std.debug.print("Misses:  {}\n", .{stats.misses});

    // Reset
    db.resetStats();

    // Database info
    const info = db.info();
    std.debug.print("Entries: {}\n", .{info.entries});
    std.debug.print("Collections: {}\n", .{info.collection_count});

    // Maintenance
    try db.checkpoint();
    try db.compact();
}
```
