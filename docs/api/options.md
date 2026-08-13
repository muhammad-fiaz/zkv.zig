# Options

The `Options` struct configures database behavior at open time.

## All Fields

```zig
const options = zkv.Options{
    .path = "data.zkv",               // Database file path
    .create_if_missing = true,         // Create file if it doesn't exist
    .read_only = false,                // Open in read only mode
    .page_size = 4096,                 // Page size in bytes
    .max_key_size = 1024,              // Max key length in bytes
    .max_value_size = 1024 * 1024,     // Max value length (1 MB)
    .cache_size_bytes = 1024 * 1024,   // Cache size (1 MB)
    .checksum = .crc32c,               // Checksum algorithm
    .compression = .none,              // Compression algorithm
    .wal_enabled = true,               // Enable write ahead log
};
```

## Field Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `path` | `[]const u8` | `"data.zkv"` | File path for the database |
| `create_if_missing` | `bool` | `true` | Create the file on open if absent |
| `read_only` | `bool` | `false` | Disallow writes when true |
| `page_size` | `u32` | `4096` | Storage page size in bytes |
| `max_key_size` | `usize` | `1024` | Maximum allowed key length |
| `max_value_size` | `usize` | `1048576` | Maximum allowed value length |
| `cache_size_bytes` | `usize` | `1048576` | In memory cache budget |
| `checksum` | `ChecksumKind` | `.crc32c` | Integrity checksum algorithm |
| `compression` | `Compression` | `.none` | Value compression codec |
| `wal_enabled` | `bool` | `true` | Write ahead log for durability |

> [!IMPORTANT]
> The write ahead log (WAL) ensures durability. Disable only if you can afford to lose recent writes.

## Compression Formats

| Format | Description |
|--------|-------------|
| `.none` | No compression (default, fastest) |
| `.zstd` | Zstandard — high ratio, fast (external dep) |
| `.brotli` | Brotli — excellent ratio (external dep) |
| `.gzip` | gzip — widely compatible (stdlib) |
| `.lzma` | LZMA — high ratio, slower (stdlib, decompress only) |
| `.xz` | XZ — high ratio (stdlib, decompress only) |

> [!NOTE]
> Compression works automatically on all reads/writes. The format is detected from metadata when reopening a database.

## Checksum Algorithms

| Algorithm | Description |
|-----------|-------------|
| `.crc32c` | CRC32C — hardware accelerated on x86_64 |
| `.xxhash` | xxHash — fast non cryptographic hash |

## Export/Import Options

```zig
// ExportOptions
.{
    .format = .raw_snapshot,  // .raw_snapshot, .jsonl, or .csv
}

// ImportOptions
.{
    .format = .raw_snapshot,  // .raw_snapshot, .jsonl, or .csv
}
```

## SearchOptions

```zig
.{
    .prefix = "user:",        // Filter by key prefix
    .limit = 100,             // Max results
    .offset = 0,              // Skip first N results
    .from = null,             // Range start (inclusive)
    .to = null,               // Range end (exclusive)
}
```

## SortOptions

```zig
.{
    .limit = 50,              // Max results after sorting
}
```

## FilterOptions

```zig
.{
    .limit = 100,             // Max results
    .offset = 0,              // Skip first N
}
```
