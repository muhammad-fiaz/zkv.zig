# TTL

Set expiration times on keys with millisecond precision.

> [!IMPORTANT]
> Expired keys are not automatically removed. Call `purgeExpired()` to remove them.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/ttl.zkv",
    });
    defer db.close();

    // Set time to 0
    db.setTime(0);

    // Create keys with TTL
    try db.putTTL("session:abc", "active", 1000);
    try db.putTTL("session:def", "active", 500);

    // Both exist at t=0
    std.debug.print("abc at t=0: {s}\n", .{db.get("session:abc") orelse "null"});

    // Advance to t=600 — session:def expired
    db.setTime(600);
    const purged = try db.purgeExpired();
    std.debug.print("Purged {} expired keys\n", .{purged});
}
```
