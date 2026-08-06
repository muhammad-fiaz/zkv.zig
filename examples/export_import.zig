const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/export_import.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    const configs = db.collection("configs");

    try users.set("1:name", "Alice");
    try users.set("1:email", "alice@example.com");
    try users.set("2:name", "Bob");
    try configs.set("theme", "dark");

    // === Backup & Restore ===
    std.debug.print("=== Backup & Restore ===\n", .{});
    const backup = try db.exportData(.raw_snapshot);
    defer std.heap.page_allocator.free(backup);
    std.debug.print("Backup: {} bytes\n", .{backup.len});

    var restored = try zkv.Database.open(allocator, .{
        .path = "examples/export_restored.zkv",
    });
    defer restored.close();

    const count = try restored.importData(backup, .raw_snapshot);
    std.debug.print("Restored {} entries\n", .{count});

    // === JSONL Export ===
    std.debug.print("\n=== JSONL Export ===\n", .{});
    const json = try db.exportData(.jsonl);
    defer std.heap.page_allocator.free(json);
    std.debug.print("{s}\n", .{json});

    // === CSV Export ===
    std.debug.print("=== CSV Export ===\n", .{});
    const csv = try db.exportData(.csv);
    defer std.heap.page_allocator.free(csv);
    std.debug.print("{s}\n", .{csv});

    // === In-Memory Snapshot ===
    std.debug.print("=== Snapshot ===\n", .{});
    var snapshot = db.getSnapshot();
    defer snapshot.deinit(allocator);
    std.debug.print("Snapshot: {} entries\n", .{snapshot.items.len});
    for (snapshot.items) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }
}
