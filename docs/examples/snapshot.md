# Snapshot

Take an in memory snapshot of all entries at a point in time. Useful for consistent reads without locking the database.

> [!NOTE]
> Snapshots are in memory only and lost when the process exits. For persistent copies, use `exportData(.raw_snapshot)` instead.

## Usage

```zig
var snapshot = db.getSnapshot();
defer snapshot.deinit(allocator);

for (snapshot.items) |entry| {
    std.debug.print("{s} = {s}\n", .{ entry.key, entry.value });
}
```

## Full Example

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var db = try zkv.Database.open(allocator, .{
        .path = "examples/snapshot.zkv",
    });
    defer db.close();

    const users = db.collection("users");
    const configs = db.collection("configs");

    try users.set("1:name", "Alice");
    try users.set("2:name", "Bob");
    try configs.set("theme", "dark");

    // Take in memory snapshot.
    var snapshot = db.getSnapshot();
    defer snapshot.deinit(allocator);

    std.debug.print("Snapshot: {} entries\n", .{snapshot.items.len});
    for (snapshot.items) |entry| {
        std.debug.print("  {s} = {s}\n", .{ entry.key, entry.value });
    }
}
```

## When to Use

- Consistent reads across multiple keys
- Export a point in time view of the database
- Debug or inspect database contents
- Feed data to serialization without locking

## Snapshot vs Backup

| Feature | Snapshot | Backup |
|---------|----------|--------|
| Storage | In memory (`ArrayList`) | File on disk |
| Speed | Fast (no I/O) | Slower (writes to disk) |
| Persistence | Lost when process exits | Permanent |
| Use case | Read only inspection | Disaster recovery |
