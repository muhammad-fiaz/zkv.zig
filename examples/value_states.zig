const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/value_states.zkv",
    });
    defer db.close();

    const users = db.collection("users");

    std.debug.print("=== Key States Demo ===\n\n", .{});

    // 1. Missing key — does not exist
    std.debug.print("--- Missing Key ---\n", .{});
    std.debug.print("missing exists: {}\n", .{users.exists("missing")});
    std.debug.print("missing get:    {}\n", .{users.get("missing") == null});

    // 2. Normal value
    std.debug.print("\n--- Normal Value ---\n", .{});
    try users.set("name", "Alice");
    std.debug.print("name exists: {}\n", .{users.exists("name")});
    std.debug.print("name value:  {s}\n", .{users.get("name").?});

    // 3. Empty value — key exists, zero bytes
    std.debug.print("\n--- Empty Value ---\n", .{});
    try users.set("bio", "");
    std.debug.print("bio exists: {}\n", .{users.exists("bio")});
    std.debug.print("bio value:  (len={})\n", .{users.get("bio").?.len});
    std.debug.print("bio is empty: {}\n", .{users.get("bio").?.len == 0});

    // 4. State transitions
    std.debug.print("\n--- State Transitions ---\n", .{});

    // Missing → Value
    try users.set("transitions:1", "value");
    std.debug.print("Missing→Value: {s}\n", .{users.get("transitions:1").?});

    // Value → Empty
    try users.set("transitions:1", "");
    std.debug.print("Value→Empty: len={}\n", .{users.get("transitions:1").?.len});

    // Empty → Value
    try users.set("transitions:1", "restored");
    std.debug.print("Empty→Value: {s}\n", .{users.get("transitions:1").?});

    // Value → Missing (delete)
    try users.delete("transitions:1");
    std.debug.print("Value→Missing: exists={}\n", .{users.exists("transitions:1")});

    // 5. Count includes all existing keys (empty values count)
    std.debug.print("\n--- Count Semantics ---\n", .{});
    try users.set("count:a", "value");
    try users.set("count:b", "");
    std.debug.print("Count (a=value, b=empty): {}\n", .{users.count()});

    // 6. Pop: get value then delete key
    std.debug.print("\n--- Pop (Get + Delete) ---\n", .{});
    try users.set("pop_me", "treasure");
    if (users.get("pop_me")) |val| {
        std.debug.print("Popped: {s}\n", .{val});
        try users.delete("pop_me");
    }
    std.debug.print("After pop: exists={}\n", .{users.exists("pop_me")});

    // 7. Prefix iteration includes all states
    std.debug.print("\n--- Prefix with All States ---\n", .{});
    try users.set("pfx:1", "data");
    try users.set("pfx:2", "");
    try users.set("pfx:3", "third");
    var iter = users.prefix("pfx:");
    while (iter.next()) |entry| {
        std.debug.print("  {s} = (len={})\n", .{ entry.key, entry.value.len });
    }

    // 8. Clear removes all states
    std.debug.print("\n--- Clear ---\n", .{});
    std.debug.print("Before clear: {} entries\n", .{users.count()});
    _ = try users.clear();
    std.debug.print("After clear:  {} entries\n", .{users.count()});
}
