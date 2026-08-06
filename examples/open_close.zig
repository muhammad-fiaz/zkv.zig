const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    std.debug.print("=== Database Lifecycle ===\n", .{});
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/sessions.zkv",
        });

        const sessions = db.collection("sessions");
        try sessions.set("abc123:user", "alice");
        try sessions.set("abc123:expires", "1700000000");
        try sessions.set("def456:user", "bob");
        std.debug.print("Created {} session entries\n", .{sessions.count()});
        db.close();
    }
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/sessions.zkv",
        });
        defer db.close();

        const sessions = db.collection("sessions");
        std.debug.print("Fresh database: {} entries (data was in-memory only)\n", .{sessions.count()});

        try sessions.set("abc123:user", "alice");
        try sessions.set("abc123:expires", "1700000000");
        std.debug.print("Repopulated: {} entries\n", .{sessions.count()});
    }

    std.debug.print("\n=== Read-Only Mode ===\n", .{});
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/sessions.zkv",
            .read_only = true,
        });
        defer db.close();

        const sessions = db.collection("sessions");
        const result = sessions.set("new:key", "value");
        std.debug.print("Write in read-only mode: {}\n", .{result == error.ReadOnlyDatabase});
    }
}
