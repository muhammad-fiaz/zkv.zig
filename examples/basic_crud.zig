const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/basic_crud.zkv",
    });
    defer db.close();

    const users = db.collection("users");

    // === CREATE ===
    std.debug.print("=== CREATE ===\n", .{});
    try users.set("1:name", "Alice");
    try users.set("1:age", "30");
    try users.set("1:email", "alice@example.com");
    try users.set("2:name", "Bob");
    try users.set("2:age", "25");

    // Empty value — key exists, zero bytes
    try users.set("1:bio", "");

    std.debug.print("Created {} entries\n", .{users.count()});

    // === READ ===
    std.debug.print("\n=== READ ===\n", .{});
    if (users.get("1:name")) |name| std.debug.print("users[1:name] = {s}\n", .{name});
    if (users.get("1:age")) |age| std.debug.print("users[1:age] = {s}\n", .{age});
    if (users.get("2:name")) |name| std.debug.print("users[2:name] = {s}\n", .{name});

    // Missing key returns null
    std.debug.print("users[1:phone] exists = {}\n", .{users.exists("1:phone")});
    std.debug.print("users[1:phone] get = {}\n", .{users.get("1:phone") == null});

    // Empty value exists but has zero length
    std.debug.print("users[1:bio] exists = {}\n", .{users.exists("1:bio")});
    std.debug.print("users[1:bio] len = {}\n", .{users.get("1:bio").?.len});

    // === UPDATE ===
    std.debug.print("\n=== UPDATE ===\n", .{});
    std.debug.print("Before: users[1:age] = {s}\n", .{users.get("1:age") orelse "missing"});
    try users.set("1:age", "31");
    try users.set("1:email", "alice.new@example.com");
    std.debug.print("After:  users[1:age] = {s}\n", .{users.get("1:age") orelse "missing"});
    std.debug.print("After:  users[1:email] = {s}\n", .{users.get("1:email") orelse "missing"});

    // Update overwrites existing value
    try users.set("3:name", "Charlie");
    try users.set("3:name", "Charlie Jr.");
    std.debug.print("users[3:name] = {s}\n", .{users.get("3:name") orelse "missing"});

    // Update empty → value
    try users.set("1:bio", "Zig developer");
    std.debug.print("users[1:bio] = {s}\n", .{users.get("1:bio") orelse "missing"});

    // === POP (get + delete) ===
    std.debug.print("\n=== POP ===\n", .{});
    if (users.get("2:name")) |name| {
        std.debug.print("Popping users[2:name] = {s}\n", .{name});
        try users.delete("2:name");
    }
    std.debug.print("users[2:name] exists after pop = {}\n", .{users.exists("2:name")});

    // Pop missing key — no-op
    const missing = users.get("nonexistent");
    if (missing == null) {
        std.debug.print("Pop nonexistent key: no-op\n", .{});
    }

    // === DELETE ===
    std.debug.print("\n=== DELETE ===\n", .{});
    std.debug.print("Before delete: users[2:age] exists = {}\n", .{users.exists("2:age")});
    try users.delete("2:age");
    std.debug.print("After delete:  users[2:age] exists = {}\n", .{users.exists("2:age")});
    std.debug.print("users[2:age] get = {}\n", .{users.get("2:age") == null});

    // Delete nonexistent key — no error
    try users.delete("nonexistent");
    std.debug.print("Delete nonexistent: no error\n", .{});

    // === EXISTS ===
    std.debug.print("\n=== EXISTS ===\n", .{});
    std.debug.print("users[1:name] exists = {}\n", .{users.exists("1:name")});
    std.debug.print("users[2:age] exists  = {}\n", .{users.exists("2:age")});

    // === COUNT ===
    std.debug.print("\n=== COUNT ===\n", .{});
    std.debug.print("Total entries: {}\n", .{users.count()});

    // === KEYS AND VALUES ===
    std.debug.print("\n=== KEYS AND VALUES ===\n", .{});
    var keys = users.keys();
    defer keys.deinit(allocator);
    for (keys.items) |key| {
        std.debug.print("  key: {s}\n", .{key});
    }

    // === PREFIX ITERATION ===
    std.debug.print("\n=== PREFIX ITERATION ===\n", .{});
    var iter = users.prefix("1:");
    while (iter.next()) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }

    // === CLEAR ===
    std.debug.print("\n=== CLEAR ===\n", .{});
    std.debug.print("Before clear: {} entries\n", .{users.count()});
    _ = try users.clear();
    std.debug.print("After clear:  {} entries\n", .{users.count()});
}
