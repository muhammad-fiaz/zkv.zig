# Backup and Restore

The simplest way to copy a database. Use `exportData()` and `importData()` with `.raw_snapshot` for lossless, full fidelity copies.

> [!NOTE]
> The `.raw_snapshot` format produces a binary copy that is fast but not portable to other tools. For interoperability, use `.jsonl` or `.csv` instead.

## Backup

```zig
const backup = try db.exportData(.raw_snapshot);
defer std.heap.page_allocator.free(backup);
```

## Restore

```zig
var restored = try zkv.Database.open(allocator, .{
    .path = "restored.zkv",
});
defer restored.close();

const count = try restored.importData(backup, .raw_snapshot);
std.debug.print("Restored {} entries\n", .{count});
```

## Full Example

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    // Create source database.
    var source = try zkv.Database.open(allocator, .{
        .path = "examples/backup_source.zkv",
    });
    defer source.close();

    const users = source.collection("users");
    const configs = source.collection("configs");

    try users.set("1:name", "Alice");
    try users.set("1:email", "alice@example.com");
    try users.set("2:name", "Bob");
    try configs.set("theme", "dark");

    std.debug.print("Source: {} users, {} configs\n", .{ users.count(), configs.count() });

    // Backup: export to buffer, then import into new database.
    const backup_data = try source.exportData(.raw_snapshot);
    defer std.heap.page_allocator.free(backup_data);

    std.debug.print("Backup: {} bytes\n", .{backup_data.len});

    // Restore: import from buffer.
    var restored = try zkv.Database.open(allocator, .{
        .path = "examples/backup_restored.zkv",
    });
    defer restored.close();

    const count = try restored.importData(backup_data, .raw_snapshot);
    std.debug.print("Restored {} entries\n", .{count});

    // Verify.
    const restored_users = restored.collection("users");
    const restored_configs = restored.collection("configs");

    if (restored_users.get("1:name")) |n| std.debug.print("users[1:name] = {s}\n", .{n});
    if (restored_users.get("2:name")) |n| std.debug.print("users[2:name] = {s}\n", .{n});
    if (restored_configs.get("theme")) |t| std.debug.print("configs[theme] = {s}\n", .{t});
}
```

## When to Use

- **Backup**: Schedule periodic backups for disaster recovery
- **Restore**: Recover from a corrupted database
- **Clone**: Create a copy of a database for testing

## Backup vs Export

| Feature | `exportData(.raw_snapshot)` | `exportData(.jsonl)` / `.csv` |
|---------|----------------------------|-------------------------------|
| Format | ZKV native (lossless) | JSONL, CSV (interoperable) |
| Speed | Fast (binary copy) | Slower (text encoding) |
| Use case | Database copies | Data exchange with other tools |
