# Basic CRUD

Demonstrates all core operations using the collection first API.

> [!NOTE]
> Empty values (`""`) are distinct from missing keys. `get()` returns `null` for missing keys but returns a zero length slice for empty values.

```zig
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

    // CREATE
    try users.set("1:name", "Alice");
    try users.set("1:age", "30");
    try users.set("1:email", "alice@example.com");
    try users.set("2:name", "Bob");
    try users.set("2:age", "25");
    try users.set("1:bio", ""); // Empty value

    // READ
    if (users.get("1:name")) |name| std.debug.print("users[1:name] = {s}\n", .{name});

    // Missing key returns null
    std.debug.print("users[1:phone] exists = {}\n", .{users.exists("1:phone")});

    // Empty value exists but has zero length
    std.debug.print("users[1:bio] len = {}\n", .{users.get("1:bio").?.len});

    // UPDATE (set overwrites existing key)
    try users.set("1:age", "31");

    // POP (get + delete)
    if (users.get("2:name")) |name| {
        std.debug.print("Popping users[2:name] = {s}\n", .{name});
        try users.delete("2:name");
    }

    // DELETE
    try users.delete("2:age");

    // KEYS AND VALUES
    var keys = users.keys();
    defer keys.deinit(allocator);

    // PREFIX ITERATION
    var iter = users.prefix("1:");
    while (iter.next()) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }

    // CLEAR
    _ = try users.clear();
}
```
