# Open and Close

Database lifecycle management, in memory data behavior, and read only mode.

> [!CAUTION]
> Data in in memory mode is lost when the database is closed. Always use a file path for persistent storage.

```zig
const std = @import("std");
const zkv = @import("zkv");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    // Create and populate
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/open_close.zkv",
        });
        const sessions = db.collection("sessions");
        try sessions.set("abc:user", "alice");
        try sessions.set("def:user", "bob");
        db.close();
    }

    // Fresh database (in memory only)
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/open_close.zkv",
        });
        defer db.close();
        // Data was in memory only, starts empty
    }

    // Read only mode
    {
        var db = try zkv.Database.open(allocator, .{
            .path = "examples/open_close.zkv",
            .read_only = true,
        });
        defer db.close();
        const result = db.collection("test").set("key", "value");
        std.debug.print("Write in read only: {}\n", .{result == error.ReadOnlyDatabase});
    }
}
```
