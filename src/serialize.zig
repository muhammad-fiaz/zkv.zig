const std = @import("std");

pub const FixedBufferStream = struct {
    buffer: []u8,
    pos: usize = 0,

    pub fn init(buffer: []u8) @This() {
        return .{ .buffer = buffer };
    }

    pub fn getWritten(self: @This()) []const u8 {
        return self.buffer[0..self.pos];
    }

    pub fn writer(self: *@This()) Writer {
        return .{ .context = self };
    }

    pub fn reader(self: *@This()) Reader {
        return .{ .context = self };
    }

    pub const Writer = struct {
        context: *FixedBufferStream,

        pub fn writeAll(this: Writer, bytes: []const u8) !void {
            const end = this.context.pos + bytes.len;
            if (end > this.context.buffer.len) return error.NoSpaceLeft;
            @memcpy(this.context.buffer[this.context.pos..end], bytes);
            this.context.pos = end;
        }

        pub fn writeInt(this: Writer, comptime T: type, value: T, endian: std.builtin.Endian) !void {
            var buf: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &buf, value, endian);
            try this.writeAll(&buf);
        }

        pub fn writeByte(this: Writer, byte: u8) !void {
            try this.writeAll(&.{byte});
        }
    };

    pub const Reader = struct {
        context: *FixedBufferStream,

        pub fn readAll(this: Reader, buf: []u8) !usize {
            const available = this.context.buffer.len - this.context.pos;
            const to_read = @min(buf.len, available);
            @memcpy(buf[0..to_read], this.context.buffer[this.context.pos..][0..to_read]);
            this.context.pos += to_read;
            return to_read;
        }

        pub fn readInt(this: Reader, comptime T: type, endian: std.builtin.Endian) !T {
            var buf: [@sizeOf(T)]u8 = undefined;
            const n = try this.readAll(&buf);
            if (n < @sizeOf(T)) return error.EndOfStream;
            return std.mem.readInt(T, &buf, endian);
        }

        pub fn readByte(this: Reader) !u8 {
            if (this.context.pos >= this.context.buffer.len) return error.EndOfStream;
            const byte = this.context.buffer[this.context.pos];
            this.context.pos += 1;
            return byte;
        }

        pub fn readUntilDelimiter(this: Reader, buf: []u8, delimiter: u8) ![]u8 {
            var idx: usize = 0;
            while (idx < buf.len) : (idx += 1) {
                const byte = this.readByte() catch |err| {
                    if (err == error.EndOfStream and idx > 0) return buf[0..idx];
                    return err;
                };
                if (byte == delimiter) return buf[0..idx];
                buf[idx] = byte;
            }
            return error.StreamTooLong;
        }
    };
};

/// Wrapper around std.Io.Reader that provides the old std.io interface
/// used by serialize and export modules.
pub const IoReaderWrapper = struct {
    inner: std.Io.Reader,

    pub fn init(r: std.Io.Reader) @This() {
        return .{ .inner = r };
    }

    pub fn readAll(self: *@This(), buf: []u8) !usize {
        return self.inner.readSliceShort(buf);
    }

    pub fn readByte(self: *@This()) !u8 {
        return self.inner.takeByte();
    }

    pub fn readInt(self: *@This(), comptime T: type, endian: std.builtin.Endian) !T {
        return self.inner.takeInt(T, endian);
    }

    pub fn readUntilDelimiter(self: *@This(), buf: []u8, delimiter: u8) ![]u8 {
        var idx: usize = 0;
        while (idx < buf.len) : (idx += 1) {
            const byte = self.inner.takeByte() catch |err| {
                if (err == error.EndOfStream and idx > 0) return buf[0..idx];
                return err;
            };
            if (byte == delimiter) return buf[0..idx];
            buf[idx] = byte;
        }
        return error.StreamTooLong;
    }
};

pub const FILE_MAGIC = "ZKV\x00";
pub const FILE_VERSION: u16 = 1;

pub fn writeMagic(writer: anytype) !void {
    try writer.writeAll(FILE_MAGIC);
}

pub fn readMagic(reader: anytype) !void {
    var buf: [4]u8 = undefined;
    const n = try reader.readAll(&buf);
    if (n < 4 or !std.mem.eql(u8, &buf, FILE_MAGIC)) {
        return error.InvalidFileFormat;
    }
}

pub fn writeFileVersion(writer: anytype) !void {
    try writeU16(writer, FILE_VERSION);
}

pub fn readFileVersion(reader: anytype) !u16 {
    const v = try readU16(reader);
    if (v > FILE_VERSION) return error.UnsupportedVersion;
    return v;
}

pub fn writeU8(writer: anytype, value: u8) !void {
    try writer.writeByte(value);
}

pub fn readU8(reader: anytype) !u8 {
    return try reader.readByte();
}

pub fn writeBool(writer: anytype, value: bool) !void {
    try writer.writeByte(if (value) 1 else 0);
}

pub fn readBool(reader: anytype) !bool {
    const b = try reader.readByte();
    return b != 0;
}

pub fn writeU16(writer: anytype, value: u16) !void {
    try writer.writeInt(u16, value, .little);
}

pub fn readU16(reader: anytype) !u16 {
    return try reader.readInt(u16, .little);
}

pub fn writeU32(writer: anytype, value: u32) !void {
    try writer.writeInt(u32, value, .little);
}

pub fn readU32(reader: anytype) !u32 {
    return try reader.readInt(u32, .little);
}

pub fn writeI64(writer: anytype, value: i64) !void {
    try writer.writeInt(i64, value, .little);
}

pub fn readI64(reader: anytype) !i64 {
    return try reader.readInt(i64, .little);
}

pub fn writeU64(writer: anytype, value: u64) !void {
    try writer.writeInt(u64, value, .little);
}

pub fn readU64(reader: anytype) !u64 {
    return try reader.readInt(u64, .little);
}

pub fn writeLengthPrefixed(writer: anytype, data: []const u8) !void {
    try writeU32(writer, @intCast(data.len));
    try writer.writeAll(data);
}

pub fn readLengthPrefixedAlloc(reader: anytype, allocator: std.mem.Allocator) ![]u8 {
    const len = try readU32(reader);
    if (len > 1024 * 1024) return error.KeyTooLarge;
    const buf = try allocator.alloc(u8, len);
    errdefer allocator.free(buf);
    const n = try reader.readAll(buf);
    if (n < len) return error.EndOfStream;
    return buf;
}

test "FixedBufferStream roundtrip" {
    var buf: [128]u8 = undefined;
    var fbs = FixedBufferStream.init(&buf);
    const w = fbs.writer();
    try writeU32(w, 0xDEADBEEF);
    try writeU64(w, 0xCAFEBABE);
    try writeLengthPrefixed(w, "hello");

    fbs.pos = 0;
    const r = fbs.reader();
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try readU32(r));
    try std.testing.expectEqual(@as(u64, 0xCAFEBABE), try readU64(r));

    var allocator = std.testing.allocator;
    const str = try readLengthPrefixedAlloc(r, allocator);
    defer allocator.free(str);
    try std.testing.expectEqualStrings("hello", str);
}
