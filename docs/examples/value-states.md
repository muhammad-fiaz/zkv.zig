# Value States

ZKV supports three distinct key states with clear semantics.

> [!IMPORTANT]
> An empty value (`""`) is **not** the same as a missing key. `get()` returns `?[]const u8`, where `null` means missing and `""` means empty.

## States

| State | `get()` | `exists()` | Description |
|-------|---------|-----------|-------------|
| Missing | `null` | `false` | Key does not exist |
| Empty | `""` (len 0) | `true` | Key exists with zero bytes |
| Value | `"data"` | `true` | Key exists with data |

## Example

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");

    // Missing key
    std.debug.print("missing exists: {}\n", .{users.exists("missing")}); // false
    std.debug.print("missing get: {}\n", .{users.get("missing") == null}); // true

    // Set a value
    try users.set("name", "Alice");
    std.debug.print("name exists: {}\n", .{users.exists("name")}); // true
    std.debug.print("name value: {s}\n", .{users.get("name").?}); // Alice

    // Empty value (distinct from missing)
    try users.set("bio", "");
    std.debug.print("bio exists: {}\n", .{users.exists("bio")}); // true
    std.debug.print("bio value len: {}\n", .{users.get("bio").?.len}); // 0

    // Pop: get + delete in one call
    const popped = users.pop("name");
    std.debug.print("popped: {s}\n", .{popped.?}); // Alice
    std.debug.print("after pop: {}\n", .{users.exists("name")}); // false
}
```

## Transitions

```
Missing  -->  Value    (set with data)
Value    -->  Empty    (set with "")
Empty    -->  Value    (set with data)
Value    -->  Missing  (delete)
```

## Count Semantics

Count includes both value and empty entries. Missing keys are never counted.

```zig
try users.set("a", "value");
try users.set("b", "");
// count = 2 (both "a" and "b" exist)
```

## Use Cases

> [!TIP]
> Use empty values as flags or markers. For example, `set("seen", "")` marks an item as seen without storing data.

> [!NOTE]
> `pop()` is a convenience that combines `get()` and `delete()` in one call. Returns the value or `null` if missing.
