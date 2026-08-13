---
title: Batch Operations
description: Efficient bulk put, delete, and prefix operations in zkv.zig.
---

# Batch Operations

Batch operations accept a `Collection` parameter for namespace aware bulk writes.

## Batch Set

Insert multiple entries at once:

```zig
var batch = db.batch();
defer batch.deinit();

const users = db.collection("users");
const posts = db.collection("posts");

try batch.set(users, "1:name", "Alice");
try batch.set(users, "2:name", "Bob");
try batch.set(posts, "1:title", "Hello");
try batch.commit();
```

## Batch Delete

Remove multiple keys at once:

```zig
var batch = db.batch();
defer batch.deinit();

try batch.delete(users, "1:name");
try batch.delete(users, "2:name");
try batch.commit();
```

## Batch Clear

Clear all entries in a collection:

```zig
var batch = db.batch();
defer batch.deinit();

try batch.clear(users);
try batch.commit();
```

## Batch Rollback

Discard all queued operations without executing:

```zig
var batch = db.batch();
try batch.set(users, "1:name", "Alice");
batch.rollback(); // discard, nothing committed
```

> [!TIP]
> Use `rollback()` to safely discard a batch if you detect an error before committing.

## Delete by Prefix

Remove all keys matching a prefix:

```zig
const deleted = try users.deletePrefix("1:");
std.debug.print("Deleted {d} entries\n", .{deleted});
```

## Count by Prefix

Count entries matching a prefix:

```zig
const user_count = users.countPrefix("user:");
std.debug.print("User count: {d}\n", .{user_count});
```

## Example: Bulk Import

```zig
const users = db.collection("users");
const logs = db.collection("logs");

var batch = db.batch();
defer batch.deinit();

try batch.set(users, "1:name", "Alice");
try batch.set(users, "2:name", "Bob");
try batch.set(logs, "entry1", "log data");
try batch.set(logs, "entry2", "more logs");
try batch.commit();
```
