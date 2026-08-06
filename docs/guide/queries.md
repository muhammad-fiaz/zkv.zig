---
title: Queries
description: Search, filter, iterate, and query data in zkv.zig.
---

# Queries

## Search by Prefix

Find all entries with a given prefix:

```zig
const results = try db.search(.{ .prefix = "user:" });
defer results.deinit(allocator);

for (results.items) |entry| {
    std.debug.print("{s} = {s}\n", .{ entry.key, entry.value });
}
```

## Filter by Predicate

Filter entries with a custom function:

```zig
const results = try db.filter(null, struct {
    fn is_admin(_: void, e: zkv.Entry) bool {
        return std.mem.eql(u8, e.value, "admin");
    }
}.is_admin, .{});
defer results.deinit(allocator);
```

## Find First Match

Return the first entry matching a predicate:

```zig
const found = db.find(null, struct {
    fn is_user(_: void, e: zkv.Entry) bool {
        return std.mem.startsWith(u8, e.key, "user:");
    }
}.is_user);
```

## Find and Replace

Replace values for matching entries:

```zig
const replaced = try db.findAndReplace(null, struct {
    fn is_viewer(_: void, e: zkv.Entry) bool {
        return std.mem.eql(u8, e.value, "viewer");
    }
}.is_viewer, "moderator");
```

## Sorted Entries

Retrieve entries sorted by a comparator:

```zig
const sorted = try db.sortedEntries(null, struct {
    fn cmp(_: void, a: zkv.Entry, b: zkv.Entry) std.math.Order {
        return std.mem.order(u8, a.key, b.key);
    }
}.cmp, .{});
defer sorted.deinit(allocator);
```

## Iterator

Iterate over a key range:

```zig
var it = db.iterator("user:1", "user:3") orelse return;
while (it.next()) |entry| {
    std.debug.print("{s} => {s}\n", .{ entry.key, entry.value });
}
```

## Collection Prefix Iteration

```zig
const users = db.collection("users");
var iter = users.prefix("1:");
while (iter.next()) |entry| {
    std.debug.print("{s} = {s}\n", .{ entry.key, entry.value });
}
```

## Collection Range Query

```zig
const items = db.collection("items");
var result = items.range("a", "d");
defer result.deinit(allocator);
```
