const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/transactions.zkv",
    });
    defer db.close();

    const accounts = db.collection("accounts");
    const inventory = db.collection("inventory");

    std.debug.print("=== Scenario 1: Bank Transfer ===\n", .{});
    try accounts.set("alice:balance", "1000");
    try accounts.set("bob:balance", "500");

    var txn = try db.begin(false);
    try txn.set("accounts:alice:balance", "900");
    try txn.set("accounts:bob:balance", "600");
    try db.commitTransaction(&txn);
    std.debug.print("Alice: ${s}, Bob: ${s}\n", .{
        accounts.get("alice:balance") orelse "?",
        accounts.get("bob:balance") orelse "?",
    });

    std.debug.print("\n=== Scenario 2: Failed Transfer (Rollback) ===\n", .{});
    var txn2 = try db.begin(false);
    try txn2.set("accounts:alice:balance", "500");
    try txn2.set("accounts:bob:balance", "1000");
    try db.rollbackTransaction(&txn2);
    std.debug.print("Alice: ${s}, Bob: ${s} (unchanged)\n", .{
        accounts.get("alice:balance") orelse "?",
        accounts.get("bob:balance") orelse "?",
    });

    std.debug.print("\n=== Scenario 3: Read-Only Transaction ===\n", .{});
    var txn3 = try db.begin(true);
    const alice_balance = txn3.get("accounts:alice:balance");
    if (alice_balance) |b| std.debug.print("Alice balance: ${s}\n", .{b});
    try txn3.commit();

    std.debug.print("\n=== Scenario 4: view() - Auto-Rollback ===\n", .{});
    const view_result = try db.view({}, ?[]const u8, &(struct {
        fn read(_: void, t: *zkv.mvcc.Transaction) ?[]const u8 {
            return t.get("accounts:bob:balance");
        }
    }.read));
    if (view_result) |balance| std.debug.print("Bob balance (view): ${s}\n", .{balance});

    std.debug.print("\n=== Scenario 5: update() - Auto-Commit ===\n", .{});
    try db.update({}, void, &(struct {
        fn write(_: void, t: *zkv.mvcc.Transaction) void {
            t.set("accounts:alice:balance", "1100") catch return;
            t.set("accounts:bob:balance", "700") catch return;
        }
    }.write));
    std.debug.print("Alice: ${s}, Bob: ${s}\n", .{
        accounts.get("alice:balance") orelse "?",
        accounts.get("bob:balance") orelse "?",
    });

    std.debug.print("\n=== Scenario 6: Multi-Operation Transaction ===\n", .{});
    var txn6 = try db.begin(false);
    try txn6.set("inventory:widget:count", "50");
    try txn6.set("inventory:gadget:count", "25");
    try txn6.set("inventory:widget:price", "29.99");
    try txn6.set("inventory:gadget:price", "49.99");
    try db.commitTransaction(&txn6);
    std.debug.print("Inventory: {} items\n", .{inventory.count()});
}
