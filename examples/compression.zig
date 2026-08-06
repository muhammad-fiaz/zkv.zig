const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    // No compression (default)
    std.debug.print("=== No Compression (default) ===\n", .{});
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_none.zkv",
        });
        defer db.close();

        const items = db.collection("items");
        try items.set("key1", "Hello World");
        try items.set("key2", "Short");
        if (items.get("key1")) |val| std.debug.print("key1 = {s}\n", .{val});
        std.debug.print("Stored {} items\n\n", .{items.count()});
    }

    // Zstd compression — just set .compression = .zstd
    std.debug.print("=== Zstd Compression ===\n", .{});
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_zstd.zkv",
            .compression = .zstd,
        });
        defer db.close();

        const items = db.collection("items");
        try items.set("key1", "AAAAAAAAAA BBBBBBBBBB CCCCCCCCCC repeated data compresses very well");
        try items.set("key2", "Another value stored with automatic zstd compression");
        try items.set("key3", ""); // Empty values work too

        // Reads decompress automatically
        if (items.get("key1")) |val| std.debug.print("key1 = {s}\n", .{val});
        if (items.get("key2")) |val| std.debug.print("key2 = {s}\n", .{val});
        if (items.get("key3")) |val| std.debug.print("key3 = (empty, len={})\n", .{val.len});
        std.debug.print("Stored {} items\n\n", .{items.count()});
    }

    // Gzip compression (via Zig stdlib)
    std.debug.print("=== Gzip Compression ===\n", .{});
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_gzip.zkv",
            .compression = .gzip,
        });
        defer db.close();

        const items = db.collection("items");
        try items.set("key1", "Gzip compression uses the Zig standard library");
        try items.set("key2", "No external dependencies needed for gzip");

        if (items.get("key1")) |val| std.debug.print("key1 = {s}\n", .{val});
        if (items.get("key2")) |val| std.debug.print("key2 = {s}\n", .{val});
        std.debug.print("Stored {} items\n\n", .{items.count()});
    }

    // Brotli compression
    std.debug.print("=== Brotli Compression ===\n", .{});
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_brotli.zkv",
            .compression = .brotli,
        });
        defer db.close();

        const items = db.collection("items");
        try items.set("key1", "The quick brown fox jumps over the lazy dog");
        try items.set("key2", "Brotli compression works automatically on all writes");

        if (items.get("key1")) |val| std.debug.print("key1 = {s}\n", .{val});
        if (items.get("key2")) |val| std.debug.print("key2 = {s}\n", .{val});
        std.debug.print("Stored {} items\n\n", .{items.count()});
    }

    // Reopen compressed databases — auto-detects format from metadata
    std.debug.print("=== Auto-detect on Reopen ===\n", .{});
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_zstd.zkv",
        });
        defer db.close();
        const items = db.collection("items");
        std.debug.print("Reopened zstd db: {} items\n", .{items.count()});
        if (items.get("key1")) |val| std.debug.print("key1 = {s}\n", .{val});
    }

    // Multiple collections with different data
    std.debug.print("\n=== Mixed Collections ===\n", .{});
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/compress_mixed.zkv",
            .compression = .zstd,
        });
        defer db.close();

        const users = db.collection("users");
        const logs = db.collection("logs");

        try users.set("1:name", "Alice");
        try users.set("2:name", "Bob");

        try logs.set("entry1", "AAAAAAAAAA BBBBBBBBBB CCCCCCCCCC repeated log data");
        try logs.set("entry2", "More log entries that benefit from compression");

        std.debug.print("Users: {}, Logs: {}\n", .{ users.count(), logs.count() });

        if (users.get("1:name")) |val| std.debug.print("users[1:name] = {s}\n", .{val});
        if (logs.get("entry1")) |val| std.debug.print("logs[entry1] = {s}\n", .{val});
    }
}
