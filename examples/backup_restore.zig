const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    // Create source database.
    var source = try zkv.Database.open(allocator, .{
        .path = "examples/backup_source.zkv",
    });
    defer source.close();

    const users = source.collection("users");
    const configs = source.collection("configs");

    try users.set("1:name", "Alice");
    try users.set("1:email", "alice@example.com");
    try users.set("2:name", "Bob");
    try configs.set("theme", "dark");

    std.debug.print("Source: {} users, {} configs\n", .{ users.count(), configs.count() });

    // Backup: export to buffer, then import into new database.
    const backup_data = try source.exportData(.raw_snapshot);
    defer std.heap.page_allocator.free(backup_data);

    std.debug.print("Backup: {} bytes\n", .{backup_data.len});

    // Restore: import from buffer.
    var restored = try zkv.Database.open(allocator, .{
        .path = "examples/backup_restored.zkv",
    });
    defer restored.close();

    const count = try restored.importData(backup_data, .raw_snapshot);
    std.debug.print("Restored {} entries\n", .{count});

    // Verify.
    const restored_users = restored.collection("users");
    const restored_configs = restored.collection("configs");

    if (restored_users.get("1:name")) |n| std.debug.print("users[1:name] = {s}\n", .{n});
    if (restored_users.get("2:name")) |n| std.debug.print("users[2:name] = {s}\n", .{n});
    if (restored_configs.get("theme")) |t| std.debug.print("configs[theme] = {s}\n", .{t});
}
