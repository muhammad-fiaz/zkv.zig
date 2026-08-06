const std = @import("std");

pub const ChecksumKind = enum {
    crc32c,
    xxhash,
};

pub const Compression = enum {
    none,
    zstd,
    brotli,
    gzip,
    lzma,
    xz,
};

pub const TransactionMode = enum {
    read,
    write,
};

pub const SyncMode = enum {
    none,
    normal,
    strict,
};

pub const ExportFormat = enum {
    raw_snapshot,
    jsonl,
    csv,
};

pub const ConflictResolution = enum {
    overwrite,
    skip,
    fail,
};

pub const Options = struct {
    path: []const u8 = "data.zkv",
    create_if_missing: bool = true,
    read_only: bool = false,
    page_size: u32 = 4096,
    max_key_size: usize = 1024,
    max_value_size: usize = 1024 * 1024,
    cache_size_bytes: usize = 1024 * 1024,
    checksum: ChecksumKind = .crc32c,
    wal_enabled: bool = true,
    compression: Compression = .none,
};

pub const SearchOptions = struct {
    prefix: ?[]const u8 = null,
    limit: ?usize = null,
};

pub const FilterOptions = struct {
    limit: ?usize = null,
};

pub const SortOptions = struct {
    limit: ?usize = null,
};

pub const ReplaceOptions = struct {
    limit: ?usize = null,
};

pub const IteratorOptions = struct {
    from: ?[]const u8 = null,
    to: ?[]const u8 = null,
    limit: ?usize = null,
};

pub const ExportOptions = struct {
    format: ExportFormat = .raw_snapshot,
};

pub const ImportOptions = struct {
    format: ExportFormat = .raw_snapshot,
    on_conflict: ConflictResolution = .overwrite,
};
