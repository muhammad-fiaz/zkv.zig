const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/stats.zkv",
    });
    defer db.close();

    const metrics = db.collection("metrics");
    const users = db.collection("users");

    std.debug.print("=== Performing Operations ===\n", .{});
    try metrics.set("key1", "value1");
    try metrics.set("key2", "value2");
    try metrics.set("key3", "value3");
    _ = metrics.get("key1");
    _ = metrics.get("key1");
    _ = metrics.get("key2");
    _ = metrics.get("nonexistent");
    try metrics.delete("key3");

    std.debug.print("\n=== Statistics ===\n", .{});
    var s = db.getStats();
    std.debug.print("Reads:   {}\n", .{s.reads});
    std.debug.print("Writes:  {}\n", .{s.writes});
    std.debug.print("Deletes: {}\n", .{s.deletes});
    std.debug.print("Hits:    {}\n", .{s.hits});
    std.debug.print("Misses:  {}\n", .{s.misses});

    std.debug.print("\n=== Reset Stats ===\n", .{});
    db.resetStats();
    s = db.getStats();
    std.debug.print("After reset - Reads: {}, Writes: {}\n", .{
        s.reads,
        s.writes,
    });

    std.debug.print("\n=== Collection Info ===\n", .{});
    try users.set("1:name", "Alice");
    try users.set("1:email", "alice@example.com");
    try users.set("2:name", "Bob");
    try users.set("2:email", "bob@example.com");
    std.debug.print("Users count: {}\n", .{users.count()});

    std.debug.print("\n=== Checkpoint ===\n", .{});
    try db.checkpoint();
    std.debug.print("Checkpoint completed\n", .{});

    std.debug.print("\n=== Compact ===\n", .{});
    try db.compact();
    std.debug.print("Compaction completed\n", .{});
}
