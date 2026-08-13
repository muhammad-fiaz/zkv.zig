# Export/Import API

Export and import database contents for backup, migration, or data transfer.

## Quick Export

Export to a newly allocated buffer (no manual buffer management):

```zig
// Export to allocated buffer (caller frees with page_allocator)
const data = try db.exportData(.raw_snapshot);
defer std.heap.page_allocator.free(data);

const json = try db.exportData(.jsonl);
defer std.heap.page_allocator.free(json);

const csv = try db.exportData(.csv);
defer std.heap.page_allocator.free(csv);
```

### Export Formats

| Format | Description |
|--------|-------------|
| `.raw_snapshot` | Native binary format with ZKV header, fastest |
| `.jsonl` | JSON Lines — one JSON object per line, human readable |
| `.csv` | Comma separated values, spreadsheet compatible |

## Quick Import

Import from a buffer:

```zig
const count = try db.importData(data, .raw_snapshot);
std.debug.print("imported {d} entries\n", .{count});
```

## Streaming Export/Import

For large datasets, use the streaming API with writers/readers:

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

> [!TIP]
> Use streaming export/import for large datasets to avoid loading everything into memory.

## Snapshot

```zig
const snapshot = db.getSnapshot();
defer snapshot.deinit(allocator);

for (snapshot.items) |entry| {
    std.debug.print("{s} = {s}\n", .{ entry.key, entry.value });
}
```

## Backup and Restore

```zig
// Backup
const backup = try db.exportData(.raw_snapshot);
defer std.heap.page_allocator.free(backup);

// Restore into new database
var restored = try zkv.Database.open(allocator, .{ .path = "restored.zkv" });
defer restored.close();
const count = try restored.importData(backup, .raw_snapshot);
```

> [!IMPORTANT]
> Always test your backup and restore process. Verify data integrity after restore.

## Export to JSONL

```zig
const json = try db.exportData(.jsonl);
defer std.heap.page_allocator.free(json);
std.debug.print("{s}\n", .{json});
```

## Export to CSV

```zig
const csv = try db.exportData(.csv);
defer std.heap.page_allocator.free(csv);
std.debug.print("{s}\n", .{csv});
```
