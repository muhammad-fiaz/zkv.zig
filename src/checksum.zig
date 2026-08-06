const std = @import("std");
const options = @import("options.zig");

pub const ChecksumType = union(enum) {
    crc32c: u32,
    xxhash: u64,
};

pub const Checksum = struct {
    algorithm: options.ChecksumKind,

    pub fn init(algorithm: options.ChecksumKind) @This() {
        return .{ .algorithm = algorithm };
    }

    pub fn calculate(self: @This(), data: []const u8) ChecksumType {
        return switch (self.algorithm) {
            .crc32c => .{ .crc32c = calculateCrc32c(data) },
            .xxhash => .{ .xxhash = calculateXxhash(data) },
        };
    }

    pub fn verify(self: @This(), data: []const u8, expected: ChecksumType) bool {
        const actual = self.calculate(data);
        return switch (self.algorithm) {
            .crc32c => actual.crc32c == expected.crc32c,
            .xxhash => actual.xxhash == expected.xxhash,
        };
    }

    pub fn compute(algorithm: options.ChecksumKind, data: []const u8) u64 {
        return switch (algorithm) {
            .crc32c => calculateCrc32c(data),
            .xxhash => calculateXxhash(data),
        };
    }
};

fn calculateCrc32c(data: []const u8) u32 {
    var hasher = std.hash.crc.Crc32Iscsi.init(.{});
    hasher.update(data);
    return hasher.final();
}

fn calculateXxhash(data: []const u8) u64 {
    var hasher = std.hash.XxHash64.init(0);
    hasher.update(data);
    return hasher.final();
}

test "crc32c" {
    const data = "hello, world!";
    const cs = Checksum.init(.crc32c);
    const result = cs.calculate(data);
    try std.testing.expect(result.crc32c != 0);
    try std.testing.expect(cs.verify(data, result));
}

test "xxhash" {
    const data = "hello, world!";
    const cs = Checksum.init(.xxhash);
    const result = cs.calculate(data);
    try std.testing.expect(result.xxhash != 0);
    try std.testing.expect(cs.verify(data, result));
}
