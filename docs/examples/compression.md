# Compression

Compare compression algorithms and use them for data efficiency.

> [!TIP]
> Zstd offers the best balance of speed and compression ratio. Gzip uses the Zig standard library with no external dependencies.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    // No compression (default)
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_none.zkv",
        });
        defer db.close();
        const items = db.collection("items");
        try items.set("key1", "Hello World");
    }

    // Zstd compression
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_zstd.zkv",
            .compression = .zstd,
        });
        defer db.close();
        const items = db.collection("items");
        try items.set("key1", "AAAAAAAAAA BBBBBBBBBB CCCCCCCCCC repeated data compresses very well");
    }

    // Gzip compression (via Zig stdlib)
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_gzip.zkv",
            .compression = .gzip,
        });
        defer db.close();
        const items = db.collection("items");
        try items.set("key1", "Gzip compression uses the Zig standard library");
    }

    // Brotli compression
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_brotli.zkv",
            .compression = .brotli,
        });
        defer db.close();
        const items = db.collection("items");
        try items.set("key1", "The quick brown fox jumps over the lazy dog");
    }

    // Auto detect on reopen
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_zstd.zkv",
        });
        defer db.close();
        const items = db.collection("items");
        // Compression format auto detected from metadata
    }
}
```
