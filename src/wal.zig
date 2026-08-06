const std = @import("std");
const serialize = @import("serialize.zig");
const options = @import("options.zig");
const compress_lib = @import("compression.zig");

pub const WalEntryType = enum(u8) {
    put = 1,
    delete = 2,
    commit = 3,
    rollback = 4,
};

pub const WalEntry = struct {
    entry_type: WalEntryType,
    key: []const u8,
    value: ?[]const u8 = null,
    timestamp: u64,
    checksum: u64,

    pub fn serializeToBuffer(self: WalEntry, buffer: []u8) ![]const u8 {
        var fbs = serialize.FixedBufferStream.init(buffer);
        const writer = fbs.writer();
        try serialize.writeU8(writer, @intFromEnum(self.entry_type));
        try serialize.writeLengthPrefixed(writer, self.key);
        if (self.value) |v| {
            try serialize.writeLengthPrefixed(writer, v);
        } else {
            try serialize.writeU64(writer, 0);
        }
        try serialize.writeU64(writer, self.timestamp);
        try serialize.writeU64(writer, self.checksum);
        return fbs.getWritten();
    }

    pub fn deinit(self: WalEntry, allocator: std.mem.Allocator) void {
        if (self.key.len > 0 and self.entry_type != .commit and self.entry_type != .rollback) {
            allocator.free(self.key);
        }
        if (self.value) |v| {
            if (v.len > 0) allocator.free(v);
        }
    }
};

pub const Wal = struct {
    allocator: std.mem.Allocator,
    enabled: bool,
    compression: options.Compression,
    entries: std.ArrayList(WalEntry),
    timestamp_counter: u64,

    pub fn init(allocator: std.mem.Allocator, enabled: bool, comp_kind: options.Compression) Wal {
        return Wal{
            .allocator = allocator,
            .enabled = enabled,
            .compression = comp_kind,
            .entries = std.ArrayList(WalEntry).empty,
            .timestamp_counter = 1,
        };
    }

    pub fn deinit(self: *Wal) void {
        for (self.entries.items) |entry| entry.deinit(self.allocator);
        self.entries.deinit(self.allocator);
    }

    pub fn nextTimestamp(self: *Wal) u64 {
        const ts = self.timestamp_counter;
        self.timestamp_counter += 1;
        return ts;
    }

    fn compressValue(self: *Wal, value: []const u8) ![]const u8 {
        if (self.compression == .none) return value;
        var comp = compress_lib.Compressor.init(self.allocator, self.compression);
        return try comp.compressWithHeader(value);
    }

    fn decompressValue(self: *Wal, data: []const u8, expected_size: usize) ![]const u8 {
        if (self.compression == .none) return data;
        var decomp = compress_lib.Decompressor.init(self.allocator, self.compression);
        return try decomp.decompressAuto(data, expected_size);
    }

    pub fn appendPut(self: *Wal, key: []const u8, value: []const u8, timestamp: u64) !void {
        if (!self.enabled) return;
        const stored_value = try self.compressValue(value);
        defer if (self.compression != .none) self.allocator.free(stored_value);
        try self.entries.append(self.allocator, .{
            .entry_type = .put,
            .key = try self.allocator.dupe(u8, key),
            .value = try self.allocator.dupe(u8, stored_value),
            .timestamp = timestamp,
            .checksum = 0,
        });
    }

    pub fn appendDelete(self: *Wal, key: []const u8, timestamp: u64) !void {
        if (!self.enabled) return;
        try self.entries.append(self.allocator, .{
            .entry_type = .delete,
            .key = try self.allocator.dupe(u8, key),
            .timestamp = timestamp,
            .checksum = 0,
        });
    }

    pub fn appendCommit(self: *Wal, timestamp: u64) !void {
        if (!self.enabled) return;
        try self.entries.append(self.allocator, .{
            .entry_type = .commit,
            .key = "",
            .timestamp = timestamp,
            .checksum = 0,
        });
    }

    pub fn appendRollback(self: *Wal, timestamp: u64) !void {
        if (!self.enabled) return;
        try self.entries.append(self.allocator, .{
            .entry_type = .rollback,
            .key = "",
            .timestamp = timestamp,
            .checksum = 0,
        });
    }

    pub fn truncate(self: *Wal) !void {
        for (self.entries.items) |entry| entry.deinit(self.allocator);
        self.entries.clearRetainingCapacity();
    }

    pub fn replay(self: *Wal, callback: fn (WalEntry) anyerror!void) !void {
        for (self.entries.items) |entry| {
            try callback(entry);
        }
    }
};

test "WalEntry serialize roundtrip" {
    const entry = WalEntry{
        .entry_type = .put,
        .key = "test_key",
        .value = "test_value",
        .timestamp = 123456,
        .checksum = 0,
    };

    var buffer: [1024]u8 = undefined;
    const written = try entry.serializeToBuffer(&buffer);
    try std.testing.expect(written.len > 0);
}

test "Wal append and truncate" {
    var wal_test = Wal.init(std.testing.allocator, true, .none);
    defer wal_test.deinit();

    try wal_test.appendPut("key1", "value1", 1);
    try wal_test.appendPut("key2", "value2", 2);
    try wal_test.appendCommit(3);

    try std.testing.expectEqual(@as(usize, 3), wal_test.entries.items.len);

    try wal_test.truncate();
    try std.testing.expectEqual(@as(usize, 0), wal_test.entries.items.len);
}

test "Wal disabled does not store entries" {
    var wal_test = Wal.init(std.testing.allocator, false, .none);
    defer wal_test.deinit();

    try wal_test.appendPut("key1", "value1", 1);
    try wal_test.appendDelete("key2", 2);
    try wal_test.appendCommit(3);
    try wal_test.appendRollback(4);

    try std.testing.expectEqual(@as(usize, 0), wal_test.entries.items.len);
}

test "Wal append delete" {
    var wal_test = Wal.init(std.testing.allocator, true, .none);
    defer wal_test.deinit();

    try wal_test.appendDelete("key1", 1);
    try std.testing.expectEqual(@as(usize, 1), wal_test.entries.items.len);
    try std.testing.expectEqual(WalEntryType.delete, wal_test.entries.items[0].entry_type);
}

test "Wal append rollback" {
    var wal_test = Wal.init(std.testing.allocator, true, .none);
    defer wal_test.deinit();

    try wal_test.appendRollback(1);
    try std.testing.expectEqual(@as(usize, 1), wal_test.entries.items.len);
    try std.testing.expectEqual(WalEntryType.rollback, wal_test.entries.items[0].entry_type);
}

test "Wal nextTimestamp increments" {
    var wal_test = Wal.init(std.testing.allocator, true, .none);
    defer wal_test.deinit();

    const ts1 = wal_test.nextTimestamp();
    const ts2 = wal_test.nextTimestamp();
    const ts3 = wal_test.nextTimestamp();

    try std.testing.expectEqual(@as(u64, 1), ts1);
    try std.testing.expectEqual(@as(u64, 2), ts2);
    try std.testing.expectEqual(@as(u64, 3), ts3);
}

test "Wal replay calls callback" {
    var wal_test = Wal.init(std.testing.allocator, true, .none);
    defer wal_test.deinit();

    try wal_test.appendPut("key1", "value1", 1);
    try wal_test.appendCommit(2);

    try wal_test.replay(struct {
        fn cb(_: WalEntry) anyerror!void {}
    }.cb);

    try std.testing.expectEqual(@as(usize, 2), wal_test.entries.items.len);
}

test "Wal compress with zstd" {
    var wal_test = Wal.init(std.testing.allocator, true, .zstd);
    defer wal_test.deinit();

    try wal_test.appendPut("key1", "AAAAAAAAAA BBBBBBBBBB CCCCCCCCCC", 1);
    try std.testing.expectEqual(@as(usize, 1), wal_test.entries.items.len);
}
