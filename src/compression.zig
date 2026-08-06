const std = @import("std");
const options = @import("options.zig");

pub const COMPRESS_MAGIC_NONE: u8 = 0x00;
pub const COMPRESS_MAGIC_ZSTD: u8 = 0x01;
pub const COMPRESS_MAGIC_BROTLI: u8 = 0x02;
pub const COMPRESS_MAGIC_GZIP: u8 = 0x03;
pub const COMPRESS_MAGIC_LZMA: u8 = 0x04;
pub const COMPRESS_MAGIC_XZ: u8 = 0x05;

pub fn compressionMagic(kind: options.Compression) u8 {
    return switch (kind) {
        .none => COMPRESS_MAGIC_NONE,
        .zstd => COMPRESS_MAGIC_ZSTD,
        .brotli => COMPRESS_MAGIC_BROTLI,
        .gzip => COMPRESS_MAGIC_GZIP,
        .lzma => COMPRESS_MAGIC_LZMA,
        .xz => COMPRESS_MAGIC_XZ,
    };
}

pub fn magicToCompression(magic: u8) ?options.Compression {
    return switch (magic) {
        COMPRESS_MAGIC_NONE => .none,
        COMPRESS_MAGIC_ZSTD => .zstd,
        COMPRESS_MAGIC_BROTLI => .brotli,
        COMPRESS_MAGIC_GZIP => .gzip,
        COMPRESS_MAGIC_LZMA => .lzma,
        COMPRESS_MAGIC_XZ => .xz,
        else => null,
    };
}

pub fn isCompressionSupported(kind: options.Compression) bool {
    return switch (kind) {
        .none, .zstd, .brotli, .gzip => true,
        .lzma, .xz => true,
    };
}

pub const Compressor = struct {
    kind: options.Compression,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, kind: options.Compression) Compressor {
        return .{ .kind = kind, .allocator = allocator };
    }

    pub fn compress(self: *Compressor, data: []const u8) ![]u8 {
        return switch (self.kind) {
            .none => {
                const result = try self.allocator.alloc(u8, data.len);
                @memcpy(result, data);
                return result;
            },
            .zstd => {
                const zstd = @import("zstd");
                return zstd.compress(self.allocator, data, 3);
            },
            .brotli => {
                const brotli = @import("brotli");
                return brotli.compress(self.allocator, data);
            },
            .gzip => {
                return compressGzip(self.allocator, data);
            },
            .lzma => {
                return compressLzma(self.allocator, data);
            },
            .xz => {
                return compressXz(self.allocator, data);
            },
        };
    }

    pub fn compressWithHeader(self: *Compressor, data: []const u8) ![]u8 {
        const compressed = try self.compress(data);
        defer self.allocator.free(compressed);
        const magic = compressionMagic(self.kind);
        const result = try self.allocator.alloc(u8, compressed.len + 1);
        result[0] = magic;
        @memcpy(result[1..], compressed);
        return result;
    }
};

pub const Decompressor = struct {
    kind: options.Compression,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, kind: options.Compression) Decompressor {
        return .{ .kind = kind, .allocator = allocator };
    }

    pub fn decompress(self: *Decompressor, data: []const u8, expected_size: usize) ![]u8 {
        return switch (self.kind) {
            .none => {
                const result = try self.allocator.alloc(u8, data.len);
                @memcpy(result, data);
                return result;
            },
            .zstd => {
                const zstd = @import("zstd");
                return zstd.decompress(self.allocator, data, expected_size);
            },
            .brotli => {
                const brotli = @import("brotli");
                return brotli.decompress(self.allocator, data);
            },
            .gzip => {
                return decompressGzip(self.allocator, data);
            },
            .lzma => {
                return decompressLzma(self.allocator, data);
            },
            .xz => {
                return decompressXz(self.allocator, data);
            },
        };
    }

    pub fn decompressAuto(self: *Decompressor, data: []const u8, expected_size: usize) ![]u8 {
        if (data.len == 0) return error.EmptyData;
        const magic = data[0];
        if (magicToCompression(magic)) |detected| {
            if (detected == .none) {
                const result = try self.allocator.alloc(u8, data.len - 1);
                @memcpy(result, data[1..]);
                return result;
            }
            if (!isCompressionSupported(detected)) return error.CompressionNotSupported;
            var decomp = Decompressor.init(self.allocator, detected);
            return decomp.decompress(data[1..], expected_size);
        }
        return error.UnknownCompressionFormat;
    }
};

fn compressGzip(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var output = try std.Io.Writer.Allocating.initCapacity(allocator, 1024);
    var buf: [std.compress.flate.max_window_len]u8 = undefined;
    var comp = try std.compress.flate.Compress.init(&output.writer, &buf, .gzip, .default);
    try comp.writer.writeAll(data);
    try comp.finish();
    return try output.toOwnedSlice();
}

fn decompressGzip(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var input = std.Io.Reader.fixed(data);
    var buf: [std.compress.flate.max_window_len]u8 = undefined;
    var decomp = std.compress.flate.Decompress.init(&input, .gzip, &buf);

    var output = std.ArrayList(u8).empty;
    var read_buf: [4096]u8 = undefined;
    while (true) {
        const n = decomp.reader.readSliceShort(&read_buf) catch break;
        if (n == 0) break;
        try output.appendSlice(allocator, read_buf[0..n]);
    }
    return try output.toOwnedSlice(allocator);
}

fn compressLzma(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    _ = allocator;
    _ = data;
    return error.CompressionNotSupported;
}

fn decompressLzma(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var input = std.Io.Reader.fixed(data);
    var buf: [std.compress.flate.max_window_len]u8 = undefined;
    var decomp = try std.compress.lzma.Decompress.initOptions(&input, allocator, &buf, .{}, std.math.maxInt(usize));

    var output = std.ArrayList(u8).empty;
    var read_buf: [4096]u8 = undefined;
    while (true) {
        const n = decomp.reader.readSliceShort(&read_buf) catch break;
        if (n == 0) break;
        try output.appendSlice(allocator, read_buf[0..n]);
    }
    return try output.toOwnedSlice(allocator);
}

fn compressXz(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    _ = allocator;
    _ = data;
    return error.CompressionNotSupported;
}

fn decompressXz(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var input = std.Io.Reader.fixed(data);
    var buf: [std.compress.flate.max_window_len]u8 = undefined;
    var decomp = try std.compress.xz.Decompress.init(&input, allocator, &buf);

    var output = std.ArrayList(u8).empty;
    var read_buf: [4096]u8 = undefined;
    while (true) {
        const n = decomp.reader.readSliceShort(&read_buf) catch break;
        if (n == 0) break;
        try output.appendSlice(allocator, read_buf[0..n]);
    }
    return try output.toOwnedSlice(allocator);
}

test "compress and decompress none" {
    const allocator = std.testing.allocator;
    var comp = Compressor.init(allocator, .none);
    var decomp = Decompressor.init(allocator, .none);

    const data = "hello world";
    const compressed = try comp.compress(data);
    defer allocator.free(compressed);

    const decompressed = try decomp.decompress(compressed, data.len);
    defer allocator.free(decompressed);

    try std.testing.expectEqualStrings(data, decompressed);
}

test "compress with header roundtrip none" {
    const allocator = std.testing.allocator;
    var comp = Compressor.init(allocator, .none);
    var decomp = Decompressor.init(allocator, .none);

    const data = "test data for header roundtrip";
    const with_header = try comp.compressWithHeader(data);
    defer allocator.free(with_header);

    const result = try decomp.decompressAuto(with_header, data.len);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(data, result);
}

test "auto-detect compression format" {
    const allocator = std.testing.allocator;

    const data = "auto detection test data for none";
    var comp = Compressor.init(allocator, .none);
    const with_header = try comp.compressWithHeader(data);
    defer allocator.free(with_header);

    var decomp = Decompressor.init(allocator, .none);
    const result = try decomp.decompressAuto(with_header, data.len);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(data, result);
}

test "magic byte mapping" {
    try std.testing.expectEqual(COMPRESS_MAGIC_NONE, compressionMagic(.none));
    try std.testing.expectEqual(COMPRESS_MAGIC_ZSTD, compressionMagic(.zstd));
    try std.testing.expectEqual(COMPRESS_MAGIC_BROTLI, compressionMagic(.brotli));
    try std.testing.expectEqual(COMPRESS_MAGIC_GZIP, compressionMagic(.gzip));
    try std.testing.expectEqual(COMPRESS_MAGIC_LZMA, compressionMagic(.lzma));
    try std.testing.expectEqual(COMPRESS_MAGIC_XZ, compressionMagic(.xz));
    try std.testing.expectEqual(options.Compression.none, magicToCompression(COMPRESS_MAGIC_NONE).?);
    try std.testing.expectEqual(options.Compression.zstd, magicToCompression(COMPRESS_MAGIC_ZSTD).?);
    try std.testing.expectEqual(options.Compression.brotli, magicToCompression(COMPRESS_MAGIC_BROTLI).?);
    try std.testing.expectEqual(options.Compression.gzip, magicToCompression(COMPRESS_MAGIC_GZIP).?);
    try std.testing.expectEqual(options.Compression.lzma, magicToCompression(COMPRESS_MAGIC_LZMA).?);
    try std.testing.expectEqual(options.Compression.xz, magicToCompression(COMPRESS_MAGIC_XZ).?);
    try std.testing.expect(magicToCompression(0xFF) == null);
}

test "zstd compress and decompress" {
    const allocator = std.testing.allocator;
    var comp = Compressor.init(allocator, .zstd);
    var decomp = Decompressor.init(allocator, .zstd);

    const data = "AAAAAAAAAA BBBBBBBBBB CCCCCCCCCC repeated data for zstd";
    const compressed = try comp.compress(data);
    defer allocator.free(compressed);

    const decompressed = try decomp.decompress(compressed, data.len);
    defer allocator.free(decompressed);

    try std.testing.expectEqualStrings(data, decompressed);
}

test "zstd compress with header roundtrip" {
    const allocator = std.testing.allocator;
    var comp = Compressor.init(allocator, .zstd);
    var decomp = Decompressor.init(allocator, .zstd);

    const data = "zstd header roundtrip test data";
    const with_header = try comp.compressWithHeader(data);
    defer allocator.free(with_header);

    const result = try decomp.decompressAuto(with_header, data.len);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(data, result);
}

test "brotli compress and decompress" {
    const allocator = std.testing.allocator;
    var comp = Compressor.init(allocator, .brotli);
    var decomp = Decompressor.init(allocator, .brotli);

    const data = "brotli compress and decompress test data";
    const compressed = try comp.compress(data);
    defer allocator.free(compressed);

    const decompressed = try decomp.decompress(compressed, data.len);
    defer allocator.free(decompressed);

    try std.testing.expectEqualStrings(data, decompressed);
}

test "brotli compress with header roundtrip" {
    const allocator = std.testing.allocator;
    var comp = Compressor.init(allocator, .brotli);
    var decomp = Decompressor.init(allocator, .brotli);

    const data = "brotli header roundtrip test";
    const with_header = try comp.compressWithHeader(data);
    defer allocator.free(with_header);

    const result = try decomp.decompressAuto(with_header, data.len);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(data, result);
}

test "gzip compress and decompress" {
    const allocator = std.testing.allocator;
    var comp = Compressor.init(allocator, .gzip);
    var decomp = Decompressor.init(allocator, .gzip);

    const data = "gzip compress and decompress test data for zkv";
    const compressed = try comp.compress(data);
    defer allocator.free(compressed);

    const decompressed = try decomp.decompress(compressed, data.len);
    defer allocator.free(decompressed);

    try std.testing.expectEqualStrings(data, decompressed);
}

test "gzip compress with header roundtrip" {
    const allocator = std.testing.allocator;
    var comp = Compressor.init(allocator, .gzip);
    var decomp = Decompressor.init(allocator, .gzip);

    const data = "gzip header roundtrip test";
    const with_header = try comp.compressWithHeader(data);
    defer allocator.free(with_header);

    const result = try decomp.decompressAuto(with_header, data.len);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(data, result);
}

test "decompressAuto with unknown magic byte" {
    const allocator = std.testing.allocator;
    var decomp = Decompressor.init(allocator, .none);

    const data = [_]u8{ 0xFF, 0x01, 0x02, 0x03 };
    const result = decomp.decompressAuto(&data, 3);
    try std.testing.expectError(error.UnknownCompressionFormat, result);
}

test "decompressAuto with empty data" {
    const allocator = std.testing.allocator;
    var decomp = Decompressor.init(allocator, .none);

    const data: []const u8 = &.{};
    const result = decomp.decompressAuto(data, 0);
    try std.testing.expectError(error.EmptyData, result);
}

test "isCompressionSupported" {
    try std.testing.expect(isCompressionSupported(.none));
    try std.testing.expect(isCompressionSupported(.zstd));
    try std.testing.expect(isCompressionSupported(.brotli));
    try std.testing.expect(isCompressionSupported(.gzip));
    try std.testing.expect(isCompressionSupported(.lzma));
    try std.testing.expect(isCompressionSupported(.xz));
}

test "magicToCompression for all types" {
    try std.testing.expectEqual(options.Compression.none, magicToCompression(COMPRESS_MAGIC_NONE).?);
    try std.testing.expectEqual(options.Compression.zstd, magicToCompression(COMPRESS_MAGIC_ZSTD).?);
    try std.testing.expectEqual(options.Compression.brotli, magicToCompression(COMPRESS_MAGIC_BROTLI).?);
    try std.testing.expectEqual(options.Compression.gzip, magicToCompression(COMPRESS_MAGIC_GZIP).?);
    try std.testing.expectEqual(options.Compression.lzma, magicToCompression(COMPRESS_MAGIC_LZMA).?);
    try std.testing.expectEqual(options.Compression.xz, magicToCompression(COMPRESS_MAGIC_XZ).?);
    try std.testing.expect(magicToCompression(0xFF) == null);
}

test "compressionMagic for all types" {
    try std.testing.expectEqual(COMPRESS_MAGIC_NONE, compressionMagic(.none));
    try std.testing.expectEqual(COMPRESS_MAGIC_ZSTD, compressionMagic(.zstd));
    try std.testing.expectEqual(COMPRESS_MAGIC_BROTLI, compressionMagic(.brotli));
    try std.testing.expectEqual(COMPRESS_MAGIC_GZIP, compressionMagic(.gzip));
    try std.testing.expectEqual(COMPRESS_MAGIC_LZMA, compressionMagic(.lzma));
    try std.testing.expectEqual(COMPRESS_MAGIC_XZ, compressionMagic(.xz));
}
