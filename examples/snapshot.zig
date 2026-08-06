const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/snapshot.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    const configs = db.collection("configs");

    try users.set("1:name", "Alice");
    try users.set("2:name", "Bob");
    try configs.set("theme", "dark");

    // Take in-memory snapshot.
    var snapshot = db.getSnapshot();
    defer snapshot.deinit(allocator);

    std.debug.print("Snapshot: {} entries\n", .{snapshot.items.len});
    for (snapshot.items) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }
}
