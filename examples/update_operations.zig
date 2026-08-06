const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/updates.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    const counters = db.collection("counters");
    const temps = db.collection("temps");
    const perms = db.collection("perms");

    std.debug.print("=== Scenario 1: Update Specific Key ===\n", .{});
    try users.set("1:name", "Alice");
    try users.set("1:age", "30");
    try users.set("1:city", "NYC");
    std.debug.print("Before: users[1:age] = {s}\n", .{users.get("1:age") orelse "?"});
    try users.set("1:age", "31");
    try users.set("1:city", "Boston");
    std.debug.print("After:  users[1:age] = {s}\n", .{users.get("1:age") orelse "?"});
    std.debug.print("After:  users[1:city] = {s}\n", .{users.get("1:city") orelse "?"});

    std.debug.print("\n=== Scenario 2: Batch Update ===\n", .{});
    try users.set("2:name", "Bob");
    try users.set("2:role", "viewer");
    try users.set("3:name", "Charlie");
    try users.set("3:role", "viewer");
    std.debug.print("users[2:role]={s}, users[3:role]={s}\n", .{
        users.get("2:role") orelse "?",
        users.get("3:role") orelse "?",
    });

    std.debug.print("\n=== Scenario 3: Increment Counter (Transaction) ===\n", .{});
    try counters.set("clicks", "0");

    var txn = try db.begin(false);
    const current = txn.get("counters:clicks") orelse "0";
    const val = std.fmt.parseInt(u32, current, 10) catch 0;
    const new_val = try std.fmt.allocPrint(allocator, "{}", .{val + 1});
    defer allocator.free(new_val);
    try txn.set("counters:clicks", new_val);
    try db.commitTransaction(&txn);
    std.debug.print("Counter: {s}\n", .{counters.get("clicks") orelse "?"});

    std.debug.print("\n=== Scenario 4: Delete Specific Key ===\n", .{});
    try users.set("1:email", "alice@example.com");
    std.debug.print("Before: users[1:email] exists = {}\n", .{users.exists("1:email")});
    try users.delete("1:email");
    std.debug.print("After:  users[1:email] exists = {}\n", .{users.exists("1:email")});

    std.debug.print("\n=== Scenario 5: Clear Collection ===\n", .{});
    try temps.set("key1", "val1");
    try temps.set("key2", "val2");
    try perms.set("key1", "val1");
    std.debug.print("Before: temps={}, perms={}\n", .{ temps.count(), perms.count() });
    _ = try temps.clear();
    std.debug.print("After clear temps: temps={}, perms={}\n", .{ temps.count(), perms.count() });
}
