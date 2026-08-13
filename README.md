<div align="center">

# ZKV.zig

<a href="https://muhammad-fiaz.github.io/zkv.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.16%2B-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/zkv.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/zkv.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/zkv.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/zkv.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/zkv.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/zkv.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/zkv.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/zkv.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/zkv.zig"><img src="https://img.shields.io/github/license/muhammad-fiaz/zkv.zig" alt="License"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/zkv.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/zkv.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>

<p><em>A super-fast, lightweight embedded key-value database for Zig.</em></p>

[**Documentation**](https://muhammad-fiaz.github.io/zkv.zig/) | [**API Reference**](https://muhammad-fiaz.github.io/zkv.zig/api/) | [**Quick Start**](#quick-start) | [**Contributing**](CONTRIBUTING.md)

</div>

## Why ZKV?

ZKV is an **intentionally flat** embedded key-value database. No hierarchies, no document trees, no query planners. Just **key to value** at maximum speed with minimum overhead.

> [!NOTE]
> ZKV is intentionally flat. If you need nested document storage, consider a different approach.

### When to use ZKV

| Use Case | Why ZKV fits |
|----------|-------------|
| Application config/settings | Flat key-value is the natural model |
| Session/token storage | Fast writes, fast lookups, TTL support |
| Feature flags / toggles | Simple key existence checks |
| Caching layer | In-memory B+Tree with optional WAL durability |
| Embedded analytics counters | Atomic batch operations |
| IoT / edge data collection | Zero external dependencies, cross-platform |
| Local-first app state | No server, no runtime, no allocations beyond what you give it |
| Game state persistence | Lightweight, fast startup, predictable performance |

### Why flat?

A flat key-value model eliminates unnecessary overhead:

- **No schema evolution** add any key at any time
- **No type system overhead** values are byte strings, your app interprets them
- **No query planning** sorted B+Tree gives O(log n) lookups, range scans, prefix iteration
- **No ORM, no serialization layer** store exactly what you need
- **Minimal code size** the entire library compiles to a small binary

### Nested data with flat storage

You can achieve **nested logical data while keeping the storage completely flat** using key prefixes/paths:

```
Logical structure          Flat keys in ZKV
users                     users collection
  1                       1:name              = Alice
    name = Alice          1:age               = 30
    age = 30              1:profile:city      = Chennai
    profile               1:profile:country   = India
      city = Chennai
      country = India
```

The database only sees `key to value`. It doesn't need to understand that `:` represents nesting.

#### Prefix queries

```zig
const users = db.collection("users");

// Query all profile fields for user 1
var iter = users.prefix("1:profile:");
while (iter.next()) |entry| {
    std.debug.print("{s} = {s}\n", .{ entry.key, entry.value });
}
// 1:profile:city = Chennai
// 1:profile:country = India
```

#### Arbitrary depth

```zig
// Store deeply nested data, physically flat, logically nested
try users.set("1:settings:notifications:email", "true");
try users.set("1:settings:theme:dark", "1");

// Retrieve entire subtree
var settings = users.prefix("1:settings:");
while (settings.next()) |entry| {
    std.debug.print("{s} = {s}\n", .{ entry.key, entry.value });
}
```

### Separator recommendation

| Separator | Example | When to use |
|-----------|---------|-------------|
| `:` | `user:1:profile:city` | Default, works everywhere |
| `.` | `user.1.profile.city` | Dot-notation feel |
| `/` | `user/1/profile/city` | Path-like APIs |

> [!TIP]
> Treat the entire key as opaque bytes. ZKV never interprets separators.

## Quick Start

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    // Open database with default options
    var db = try zkv.Database.open(allocator, .{
        .path = "mydb.zkv",
    });
    defer db.close();

    const users = db.collection("users");

    // Create
    try users.set("1:name", "Alice");
    try users.set("1:age", "30");

    // Read
    if (users.get("1:name")) |name| {
        std.debug.print("Name: {s}\n", .{name});
    }

    // Update
    try users.set("1:age", "31");

    // Delete
    try users.delete("1:age");

    // Empty values are valid
    try users.set("1:bio", "");
    std.debug.print("Bio exists: {}\n", .{users.exists("1:bio")});

    // Count entries
    std.debug.print("Total: {}\n", .{users.count()});
}
```

## Features

- **Collection First API** Organize data with named collections using `db.collection("name")`
- **Flat Key Value Storage** No unnecessary hierarchy, no schema, maximum simplicity
- **Nested Logical Data** Achieve nested structures via key prefixes/paths while storage stays flat
- **Empty Values** Store zero length values, distinct from missing keys
- **ACID Transactions** Full support for atomic, consistent, isolated, durable operations
- **MVCC Isolation** Snapshot isolation for concurrent read/write operations
- **WAL based Crash Recovery** Write ahead logging for durability and crash recovery
- **Configurable Compression** Choose `.none`, `.zstd`, `.brotli`, `.gzip` for automatic compression; `.lzma`, `.xz` for decompression
- **TTL Support** Time to live for keys with automatic expiration and purging
- **Rich Query API** Iteration, search, find, filter, sort, and find and replace operations
- **Batch Operations** Efficient bulk set and delete operations with collection parameters
- **Backup and Restore** `exportData()` and `importData()` for lossless database copies
- **Export Import** JSONL and CSV formats for interoperability with other tools
- **Snapshots** In memory point in time snapshots via `getSnapshot()`
- **Cross Platform** Windows, Linux, macOS on x86_64 and aarch64

## Configuration

All database behavior is configured through `Options` passed to `Database.open()`:

```zig
var db = try zkv.Database.open(allocator, .{
    .path = "mydb.zkv",           // Database file path (default: "data.zkv")
    .create_if_missing = true,     // Create file if it doesn't exist (default: true)
    .read_only = false,            // Open in read-only mode (default: false)
    .page_size = 4096,             // Internal page size (default: 4096)
    .max_key_size = 1024,          // Maximum key length in bytes (default: 1024)
    .max_value_size = 1048576,     // Maximum value length in bytes (default: 1MB)
    .cache_size_bytes = 1048576,   // Cache size in bytes (default: 1MB)
    .checksum = .crc32c,           // Checksum algorithm: .crc32c or .xxhash (default: .crc32c)
    .wal_enabled = true,           // Enable write-ahead log (default: true)
    .compression = .zstd,          // Compression: .none (default), .zstd, or .brotli
});
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `path` | `[]const u8` | `"data.zkv"` | Database file path |
| `create_if_missing` | `bool` | `true` | Create file if it doesn't exist |
| `read_only` | `bool` | `false` | Open in read only mode |
| `page_size` | `u32` | `4096` | Internal B+Tree page size |
| `max_key_size` | `usize` | `1024` | Maximum key length in bytes |
| `max_value_size` | `usize` | `1048576` | Maximum value length in bytes |
| `cache_size_bytes` | `usize` | `1048576` | In memory cache size |
| `checksum` | `ChecksumKind` | `.crc32c` | Data integrity checksum (`.crc32c` or `.xxhash`) |
| `wal_enabled` | `bool` | `true` | Enable write ahead log for crash recovery |
| `compression` | `Compression` | `.none` | Compression: `.none`, `.zstd`, `.brotli`, `.gzip` (write); `.lzma`, `.xz` (decompress only) |

> [!IMPORTANT]
> `.lzma` and `.xz` support decompression only. The Zig standard library does not provide compression for these formats.

## Installation

### Stable Release

```bash
zig fetch --save https://github.com/muhammad-fiaz/zkv.zig/archive/refs/tags/0.0.1.tar.gz
```

### Nightly

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zkv.zig
```

### Local Path

```bash
git clone https://github.com/muhammad-fiaz/zkv.zig.git
```

Add to `build.zig.zon`:

```zig
.dependencies = .{
    .zkv = .{
        .path = "/path/to/zkv.zig",
    },
},
```

Configure `build.zig`:

```zig
const zkv_dep = b.dependency("zkv", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zkv", zkv_dep.module("zkv"));
```

## API Reference

### Database Lifecycle

| Method | Description |
|--------|-------------|
| `Database.open(allocator, options)` | Open or create a database |
| `Database.close()` | Close and free resources |
| `Database.collection(name)` | Get a named collection |
| `Database.batch()` | Create a batch for bulk operations |
| `Database.checkpoint()` | Flush WAL to main database |
| `Database.compact()` | Reclaim free space |
| `Database.estimateSize()` | Estimate in memory size |
| `Database.info()` | Get database info (entries, size, collections) |
| `Database.exportData(format)` | Export to buffer (raw/jsonl/csv) |
| `Database.importData(data, format)` | Import from buffer |

### Collection Operations

| Method | Description |
|--------|-------------|
| `collection.set(key, value)` | Insert or update a key value pair |
| `collection.get(key)` | Retrieve a value by key (returns `?[]const u8`) |
| `collection.delete(key)` | Remove a key value pair |
| `collection.exists(key)` | Check if a key exists |
| `collection.count()` | Get number of entries in collection |
| `collection.clear()` | Remove all entries in collection |
| `collection.entries()` | Get all key value pairs |
| `collection.keys()` | Get all keys |
| `collection.values()` | Get all values |
| `collection.iterator(from, to)` | Iterate over key ranges |
| `collection.range(from, to)` | Get entries in a key range |
| `collection.first()` | Get first entry |
| `collection.last()` | Get last entry |
| `collection.reverseIterator()` | Iterate in reverse order |
| `collection.prefix(str)` | Iterate over prefix matches |
| `collection.deletePrefix(str)` | Delete all entries with prefix |
| `collection.countPrefix(str)` | Count entries with prefix |
| `collection.isEmpty()` | Check if collection has no entries |
| `collection.size()` | Estimate collection size in bytes |

### Batch Operations

Batch operations accept a `Collection` parameter for namespace aware bulk writes:

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

| Method | Description |
|--------|-------------|
| `batch.set(collection, key, value)` | Queue a set operation |
| `batch.delete(collection, key)` | Queue a delete operation |
| `batch.clear(collection)` | Queue a clear operation |
| `batch.commit()` | Execute all queued operations atomically |
| `batch.rollback()` | Discard all queued operations |
| `batch.deinit()` | Free batch resources |

### Transactions

```zig
var txn = try db.transaction();
try txn.put("accounts:alice:balance", "900");
try txn.put("accounts:bob:balance", "600");
try db.commitTransaction(&txn);

// Or use auto-commit:
_ = try db.update({}, void, &(struct {
    fn write(_: void, txn: *zkv.mvcc.Transaction) void {
        txn.put("key", "value") catch return;
    }
}.write));
```

| Method | Description |
|--------|-------------|
| `db.begin(read_only)` | Begin a transaction |
| `db.transaction()` | Convenience: begin write transaction |
| `db.readTransaction()` | Convenience: begin read only transaction |
| `db.commitTransaction(&txn)` | Commit and apply transaction |
| `db.rollbackTransaction(&txn)` | Rollback transaction |
| `db.view(context, T, func)` | Auto rollback read transaction |
| `db.update(context, T, func)` | Auto commit write transaction |

> [!NOTE]
> `commitTransaction` calls `txn.deinit()` internally. Do not call `deinit` again.

### Query Operations

| Method | Description |
|--------|-------------|
| `db.search(options)` | Search by prefix |
| `db.filter(context, predicate, options)` | Filter entries by predicate |
| `db.find(context, predicate)` | Find first matching entry |
| `db.findAndReplace(context, predicate, new_value)` | Replace matching values |
| `db.sortedEntries(context, comparator, options)` | Sort entries by custom comparator |

### Export Import

| Method | Description |
|--------|-------------|
| `db.exportTo(writer, options)` | Export to writer (raw/jsonl/csv) |
| `db.importFrom(reader, options)` | Import from reader |
| `db.exportData(format)` | Export to allocated buffer |
| `db.importData(data, format)` | Import from buffer |
| `db.getSnapshot()` | Get all entries as ArrayList |

> [!TIP]
> Use `exportData` and `importData` for simple backup/restore. Use `exportTo`/`importFrom` for streaming large datasets.

## Value Semantics

ZKV supports three distinct key states:

| State | Description | `get()` returns | `exists()` returns |
|-------|-------------|----------------|-------------------|
| **Missing** | Key does not exist | `null` | `false` |
| **Empty** | Key exists with zero length value | `""` (empty slice) | `true` |
| **Value** | Key exists with bytes | `"data"` | `true` |

```zig
// Missing key, does not exist
std.debug.print("exists: {}\n", .{users.exists("missing")}); // false
std.debug.print("get: {}\n", .{users.get("missing") == null}); // true (null)

// Empty value, key exists, zero bytes
try users.set("bio", "");
std.debug.print("exists: {}\n", .{users.exists("bio")}); // true
std.debug.print("value len: {}\n", .{users.get("bio").?.len}); // 0

// Normal value
try users.set("name", "Alice");
std.debug.print("exists: {}\n", .{users.exists("name")}); // true
std.debug.print("value: {s}\n", .{users.get("name").?}); // Alice

// Delete removes the key entirely
try users.delete("name");
std.debug.print("exists: {}\n", .{users.exists("name")}); // false
```

> [!IMPORTANT]
> Empty values are stored as valid entries with zero length byte strings. They are **not** the same as missing keys or null values.

## Building

```bash
zig build                  # Build library
zig build test             # Run all tests
zig build run-all-examples # Run all examples

# Individual examples
zig build run-basic_crud
zig build run-transactions
zig build run-batch_operations
zig build run-export_import
zig build run-backup_restore
zig build run-export_jsonl
zig build run-export_csv
zig build run-snapshot
zig build run-query_operations
zig build run-open_close
zig build run-compression
zig build run-statistics
zig build run-ttl
zig build run-update_operations
zig build run-value_states
```

## Testing

```bash
zig build test             # Run all unit tests
zig build -Dtarget=x86_64-linux-gnu test  # Cross compile test
zig build -Dtarget=aarch64-macos test     # Cross compile test
```

## Documentation

Full documentation is available at [muhammad-fiaz.github.io/zkv.zig](https://muhammad-fiaz.github.io/zkv.zig/)

- [Getting Started](https://muhammad-fiaz.github.io/zkv.zig/guide/getting-started)
- [API Reference](https://muhammad-fiaz.github.io/zkv.zig/api/)
- [Examples](https://muhammad-fiaz.github.io/zkv.zig/examples/)

## Performance

ZKV is designed for maximum throughput with minimal overhead:

- **B+Tree storage** sorted keys give O(log n) lookups and efficient range scans
- **In memory indexing** all keys kept sorted in memory for fast iteration
- **WAL batching** write ahead log batches I/O for sequential writes
- **Internal compression** automatic zstd/brotli compression with zero configuration
- **No runtime dependencies** pure Zig, no allocator surprises
- **Zero copy iteration** iterators return slices into existing data

## Related Projects

- For **env.zig** (.env parsing), check out **[env.zig](https://github.com/muhammad-fiaz/env.zig)**
- For **TUI** support, check out **[tui.zig](https://github.com/muhammad-fiaz/tui.zig)**
- For **args parsing** support, check out **[args.zig](https://github.com/muhammad-fiaz/args.zig)**
- For **HTTP client/server** support, check out **[httpx.zig](https://github.com/muhammad-fiaz/httpx.zig)**
- For **Sqlite** support, check out **[sqlite.zig](https://github.com/muhammad-fiaz/sqlite.zig)**

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License, see the [LICENSE](LICENSE) file for details.

Copyright (c) 2026 Muhammad Fiaz

## Support

If you find this project helpful, consider supporting it:

- Star this repository
- Report bugs and suggest features
- [Sponsor on GitHub](https://github.com/sponsors/muhammad-fiaz)
- [Buy me a coffee](https://pay.muhammadfiaz.com)
