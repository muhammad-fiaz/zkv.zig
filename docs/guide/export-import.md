---
title: Export & Import
description: Export and import database snapshots in multiple formats with zkv.zig.
---

# Export & Import

## Quick Export

Export to a newly allocated buffer:

```zig
const data = try db.exportData(.raw_snapshot);
defer std.heap.page_allocator.free(data);

const json = try db.exportData(.jsonl);
defer std.heap.page_allocator.free(json);

const csv = try db.exportData(.csv);
defer std.heap.page_allocator.free(csv);
```

## Quick Import

Import from a buffer:

```zig
const count = try db.importData(data, .raw_snapshot);
std.debug.print("Imported {d} entries\n", .{count});
```

## Formats

| Format | Description |
|--------|-------------|
| `.raw_snapshot` | Native binary format with ZKV header, fastest |
| `.jsonl` | JSON Lines — one JSON object per line, human-readable |
| `.csv` | Comma-separated values, spreadsheet-compatible |

## Streaming Export/Import

For large datasets, use the streaming API:

```zig
// Export to file
var file = try std.fs.cwd().createFile("backup.zkv", .{});
defer file.close();
try db.exportTo(file.writer(), .{ .format = .raw_snapshot });

// Import from file
var file2 = try std.fs.cwd().openFile("backup.zkv", .{});
defer file2.close();
const imported = try db.importFrom(file2.reader(), .{ .format = .raw_snapshot });
```

## Backup and Restore

```zig
// Backup
const backup = try db.exportData(.raw_snapshot);
defer std.heap.page_allocator.free(backup);

// Restore
var restored = try zkv.Database.open(allocator, .{ .path = "restored.zkv" });
defer restored.close();
const count = try restored.importData(backup, .raw_snapshot);
```

## Get Snapshot

```zig
const snapshot = db.getSnapshot();
defer snapshot.deinit(allocator);

for (snapshot.items) |entry| {
    std.debug.print("{s} = {s}\n", .{ entry.key, entry.value });
}
```
