---
title: CRUD Operations
description: Create, read, update, and delete key value pairs in zkv.zig.
---

# CRUD Operations

## Open and Close

```zig
var db = try zkv.Database.open(allocator, .{ .path = "data.zkv" });
defer db.close();
```

## Collection First API

All CRUD operations go through collections:

```zig
const users = db.collection("users");
```

## Set (Create/Update)

Insert or update a key value pair:

```zig
try users.set("1:name", "Alice");
try users.set("2:name", "Bob");
```

## Get (Read)

Retrieve a value by key. Returns `?[]const u8`:

```zig
if (users.get("1:name")) |value| {
    std.debug.print("Found: {s}\n", .{value});
} else {
    std.debug.print("Key not found\n", .{});
}
```

## Delete

Remove a key:

```zig
try users.delete("1:name");
```

## Exists

Check if a key exists:

```zig
if (users.exists("1:name")) {
    std.debug.print("Key exists\n", .{});
}
```

## Count

Get the number of entries in a collection:

```zig
const total = users.count();
std.debug.print("Total entries: {d}\n", .{total});
```

## Clear

Remove all entries in a collection:

```zig
const cleared = try users.clear();
std.debug.print("Cleared {d} entries\n", .{cleared});
```

## Empty Values

Empty values are valid entries distinct from missing keys:

```zig
try users.set("1:bio", "");
std.debug.print("exists: {}\n", .{users.exists("1:bio")}); // true
std.debug.print("len: {}\n", .{users.get("1:bio").?.len}); // 0

// Missing key returns null
std.debug.print("missing: {}\n", .{users.get("missing") == null}); // true
```

> [!IMPORTANT]
> An empty string `""` is a valid value — it is not the same as a missing key. Use `exists()` to distinguish between the two.

## Keys and Values

```zig
var keys = users.keys();
defer keys.deinit(allocator);

var vals = users.values();
defer vals.deinit(allocator);
```

## Prefix Iteration

```zig
var iter = users.prefix("1:");
while (iter.next()) |entry| {
    std.debug.print("{s} = {s}\n", .{ entry.key, entry.value });
}
```
