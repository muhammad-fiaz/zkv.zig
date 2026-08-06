---
title: Database API
description: Full API reference for the Database struct
---

# Database API

The `Database` struct is the main entry point for zkv.zig.

## Opening and Closing

```zig
var db = try zkv.Database.open(allocator, .{
    .path = "my_data.zkv",
    .create_if_missing = true,
});
defer db.close();
```

## Collection-First API

All CRUD operations go through collections:

```zig
const users = db.collection("users");
const posts = db.collection("posts");

try users.set("1:name", "Alice");
try posts.set("1:title", "Hello");
```

## Basic CRUD

```zig
const users = db.collection("users");

// Insert or update
try users.set("1:name", "Alice");

// Retrieve — returns ?[]const u8
if (users.get("1:name")) |value| {
    std.debug.print("name = {s}\n", .{value});
}

// Delete
try users.delete("1:name");

// Check existence
if (users.exists("1:name")) {
    // key exists
}

// Count entries in collection
const total = users.count();
```

## Empty Values

```zig
// Empty value — key exists, zero bytes
try users.set("1:bio", "");
std.debug.print("exists: {}\n", .{users.exists("1:bio")}); // true
std.debug.print("len: {}\n", .{users.get("1:bio").?.len}); // 0

// Missing key — does not exist
std.debug.print("missing: {}\n", .{users.get("missing") == null}); // true (null)
```

## TTL

```zig
// Expires in 5 seconds
try db.putTTL("session", "abc123", 5000);

// Check remaining TTL
if (db.ttlRemaining("session")) |remaining| {
    std.debug.print("expires in {d}ms\n", .{remaining});
}

// Purge all expired entries
const purged = try db.purgeExpired();
```

## Batch Operations

```zig
var batch = db.batch();
defer batch.deinit();

const users = db.collection("users");
const posts = db.collection("posts");

try batch.set(users, "1:name", "Alice");
try batch.set(users, "2:name", "Bob");
try batch.set(posts, "1:title", "Hello");
try batch.delete(users, "3:name");
try batch.clear(posts);
try batch.commit();
```

## Transactions

```zig
var txn = try db.transaction();
try txn.put("key1", "value1");
try db.commitTransaction(&txn);
```

## Export/Import

```zig
var file = try std.fs.cwd().createFile("backup.zkv", .{});
defer file.close();
try db.exportTo(file.writer(), .{ .format = .raw_snapshot });

var file2 = try std.fs.cwd().openFile("backup.zkv", .{});
defer file2.close();
const imported = try db.importFrom(file2.reader(), .{ .format = .raw_snapshot });
```

## Database Info

```zig
const info = db.info();
std.debug.print("Entries: {}\n", .{info.entries});
std.debug.print("Collections: {}\n", .{info.collection_count});
std.debug.print("Size: {} bytes\n", .{info.size});
```

## Statistics

```zig
var stats = db.getStats();
std.debug.print("Reads: {}\n", .{stats.reads});
std.debug.print("Writes: {}\n", .{stats.writes});
std.debug.print("Hits: {}\n", .{stats.hits});
std.debug.print("Misses: {}\n", .{stats.misses});

db.resetStats();
```

## Collection Management

```zig
// List collections
var cols = try db.collections();
defer cols.deinit(allocator);

// Check if collection exists
if (db.hasCollection("users")) {
    // collection exists
}

// Delete collection and all its entries
const deleted = try db.deleteCollection("users");
```

## Maintenance

```zig
try db.compact();
try db.checkpoint();
const size = db.estimateSize();
```
