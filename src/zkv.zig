const std = @import("std");

pub const options = @import("options.zig");
pub const btree = @import("btree.zig");
pub const wal = @import("wal.zig");
pub const mvcc = @import("mvcc.zig");
pub const export_fn = @import("export.zig");
pub const query = @import("query.zig");
pub const stats = @import("stats.zig");
pub const compression = @import("compression.zig");
pub const serialize = @import("serialize.zig");

pub const Options = options.Options;
pub const Entry = btree.Entry;
pub const SearchOptions = options.SearchOptions;
pub const IteratorOptions = options.IteratorOptions;
pub const ExportOptions = options.ExportOptions;
pub const ImportOptions = options.ImportOptions;
pub const FilterOptions = options.FilterOptions;
pub const SortOptions = options.SortOptions;

pub const DatabaseError = error{
    DatabaseClosed,
    ReadOnlyDatabase,
    KeyTooLarge,
    ValueTooLarge,
    OutOfMemory,
    KeyAlreadyExists,
    KeyNotFound,
    CollectionNotFound,
    InvalidCollectionName,
};

pub const Database = struct {
    allocator: std.mem.Allocator,
    db_options: Options,
    tree: btree.BTree,
    wal: wal.Wal,
    mvcc_engine: mvcc.Mvcc,
    stats: stats.Stats,
    is_open: bool,
    ttls: std.StringHashMap(u64),
    current_time_ms: u64,
    collection_names: std.StringHashMap(void),

    pub fn open(allocator: std.mem.Allocator, db_options: Options) DatabaseError!Database {
        return Database{
            .allocator = allocator,
            .db_options = db_options,
            .tree = btree.BTree.init(allocator, 4),
            .wal = wal.Wal.init(allocator, db_options.wal_enabled, db_options.compression),
            .mvcc_engine = mvcc.Mvcc.init(allocator),
            .stats = stats.Stats.init(),
            .is_open = true,
            .ttls = std.StringHashMap(u64).init(allocator),
            .current_time_ms = 0,
            .collection_names = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn close(self: *Database) void {
        if (!self.is_open) return;
        self.is_open = false;
        self.tree.deinit();
        self.wal.deinit();
        self.ttls.deinit();
        self.collection_names.deinit();
    }

    pub fn put(self: *Database, key: []const u8, value: []const u8) !void {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;
        if (key.len > self.db_options.max_key_size) return error.KeyTooLarge;
        if (value.len > self.db_options.max_value_size) return error.ValueTooLarge;

        try self.tree.insert(key, value);
        const ts = self.wal.nextTimestamp();
        try self.wal.appendPut(key, value, ts);

        self.stats.incrementWrites();
    }

    pub fn putTTL(self: *Database, key: []const u8, value: []const u8, ttl_ms: u64) !void {
        try self.put(key, value);
        const expires_at = self.current_time_ms + ttl_ms;
        try self.ttls.put(key, expires_at);
    }

    pub fn get(self: *Database, key: []const u8) ?[]const u8 {
        if (!self.is_open) return null;
        self.stats.incrementReads();
        if (self.ttls.get(key)) |expires_at| {
            if (self.current_time_ms >= expires_at) {
                self.stats.incrementMisses();
                return null;
            }
        }
        const result = self.tree.lookup(key);
        if (result != null) {
            self.stats.incrementHits();
        } else {
            self.stats.incrementMisses();
        }
        return result;
    }

    pub fn delete(self: *Database, key: []const u8) !void {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;

        if (try self.tree.delete(key)) {
            _ = self.ttls.remove(key);
            const ts = self.wal.nextTimestamp();
            try self.wal.appendDelete(key, ts);
            self.stats.incrementDeletes();
        }
    }

    pub fn deletePrefix(self: *Database, prefix: []const u8) !usize {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;

        const deleted = try self.tree.deletePrefix(prefix);
        if (deleted > 0) {
            self.stats.incrementDeletes();
        }
        return deleted;
    }

    pub fn countPrefix(self: *Database, prefix: []const u8) usize {
        if (!self.is_open) return 0;
        return self.tree.countPrefix(prefix);
    }

    pub fn clear(self: *Database) !void {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;
        self.tree.clear();
        self.ttls.clearRetainingCapacity();
    }

    pub fn getSnapshot(self: *Database) std.ArrayList(Entry) {
        return self.tree.getAll();
    }

    pub fn estimateSize(self: *Database) usize {
        var total: usize = 0;
        for (self.tree.keys.items) |key| total += key.len;
        for (self.tree.values.items) |val| total += val.len;
        total += self.tree.keys.items.len * 2 * @sizeOf(usize);
        total += self.wal.entries.items.len * @sizeOf(wal.WalEntry);
        return total;
    }

    pub fn contains(self: *Database, key: []const u8) bool {
        if (!self.is_open) return false;
        return self.tree.contains(key);
    }

    pub fn count(self: *Database) usize {
        if (!self.is_open) return 0;
        return self.tree.count();
    }

    pub fn search(self: *Database, search_options: SearchOptions) !std.ArrayList(Entry) {
        if (!self.is_open) return error.DatabaseClosed;
        return query.search(&self.tree, search_options, self.allocator);
    }

    pub fn filter(self: *Database, context: anytype, predicate: fn (@TypeOf(context), Entry) bool, filter_options: FilterOptions) !std.ArrayList(Entry) {
        if (!self.is_open) return error.DatabaseClosed;
        return query.filter(&self.tree, context, predicate, filter_options, self.allocator);
    }

    pub fn sortedEntries(self: *Database, context: anytype, comparator: fn (@TypeOf(context), Entry, Entry) std.math.Order, sort_options: SortOptions) !std.ArrayList(Entry) {
        if (!self.is_open) return error.DatabaseClosed;
        var results = std.ArrayList(Entry).empty;
        for (self.tree.keys.items, self.tree.values.items) |key, value| {
            try results.append(self.allocator, .{ .key = key, .value = value });
        }
        std.sort.pdq(Entry, results.items, context, struct {
            fn lessThan(ctx: @TypeOf(context), a: Entry, b: Entry) bool {
                return @intFromEnum(comparator(ctx, a, b)) == @intFromEnum(std.math.Order.lt);
            }
        }.lessThan);
        if (sort_options.limit) |limit| {
            while (results.items.len > limit) {
                _ = results.pop();
            }
        }
        return results;
    }

    pub fn find(self: *Database, context: anytype, predicate: fn (@TypeOf(context), Entry) bool) ?Entry {
        if (!self.is_open) return null;
        for (self.tree.keys.items, self.tree.values.items) |key, value| {
            const entry = Entry{ .key = key, .value = value };
            if (predicate(context, entry)) return entry;
        }
        return null;
    }

    pub fn findAndReplace(self: *Database, context: anytype, predicate: fn (@TypeOf(context), Entry) bool, new_value: []const u8) !usize {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;
        var replaced: usize = 0;
        for (self.tree.keys.items, self.tree.values.items) |key, value| {
            const entry = Entry{ .key = key, .value = value };
            if (predicate(context, entry)) {
                try self.tree.insert(key, new_value);
                replaced += 1;
            }
        }
        return replaced;
    }

    pub fn iterator(self: *Database, from: ?[]const u8, to: ?[]const u8) ?btree.BTree.Iterator {
        if (!self.is_open) return null;
        return self.tree.iterator(from, to);
    }

    pub fn begin(self: *Database, read_only: bool) !mvcc.Transaction {
        if (!self.is_open) return error.DatabaseClosed;
        return self.mvcc_engine.begin(read_only);
    }

    pub fn transaction(self: *Database) !mvcc.Transaction {
        return self.begin(false);
    }

    pub fn readTransaction(self: *Database) !mvcc.Transaction {
        return self.begin(true);
    }

    pub fn view(self: *Database, context: anytype, comptime T: type, func: *const fn (@TypeOf(context), *mvcc.Transaction) T) !T {
        var txn = try self.begin(true);
        defer txn.deinit();
        return func(context, &txn);
    }

    pub fn update(self: *Database, context: anytype, comptime T: type, func: *const fn (@TypeOf(context), *mvcc.Transaction) T) !T {
        var txn = try self.begin(false);
        errdefer {
            _ = txn.rollback() catch {};
            txn.deinit();
        }
        const result = func(context, &txn);
        try self.commitTransaction(&txn);
        return result;
    }

    pub fn commitTransaction(self: *Database, txn: *mvcc.Transaction) !void {
        for (txn.write_set.items) |entry| {
            if (entry.value) |v| {
                try self.tree.insert(entry.key, v);
            } else {
                _ = try self.tree.delete(entry.key);
            }
        }
        try txn.commit();
        const ts = self.wal.nextTimestamp();
        try self.wal.appendCommit(ts);
        txn.deinit();
    }

    pub fn rollbackTransaction(self: *Database, txn: *mvcc.Transaction) !void {
        try txn.rollback();
        const ts = self.wal.nextTimestamp();
        try self.wal.appendRollback(ts);
        txn.deinit();
    }

    pub fn exportTo(self: *Database, writer: anytype, export_options: ExportOptions) !void {
        if (!self.is_open) return error.DatabaseClosed;
        try export_fn.exportTo(&self.tree, writer, export_options);
    }

    pub fn importFrom(self: *Database, reader: anytype, import_options: ImportOptions) !usize {
        if (!self.is_open) return error.DatabaseClosed;
        return export_fn.importFrom(&self.tree, reader, import_options);
    }

    /// Export database to a newly allocated buffer. Caller must free with page_allocator.
    pub fn exportData(self: *Database, format: options.ExportFormat) ![]u8 {
        if (!self.is_open) return error.DatabaseClosed;
        const estimated = @max(self.tree.count() * 64, 4096);
        const buf = try std.heap.page_allocator.alloc(u8, estimated);
        errdefer std.heap.page_allocator.free(buf);
        var fbs = serialize.FixedBufferStream.init(buf);
        export_fn.exportTo(&self.tree, fbs.writer(), .{ .format = format }) catch {
            std.heap.page_allocator.free(buf);
            const big_buf = try std.heap.page_allocator.alloc(u8, estimated * 4);
            var fbs2 = serialize.FixedBufferStream.init(big_buf);
            try export_fn.exportTo(&self.tree, fbs2.writer(), .{ .format = format });
            const written = fbs2.getWritten();
            const result = try std.heap.page_allocator.alloc(u8, written.len);
            @memcpy(result, written);
            std.heap.page_allocator.free(big_buf);
            return result;
        };
        const written = fbs.getWritten();
        const result = try std.heap.page_allocator.alloc(u8, written.len);
        @memcpy(result, written);
        std.heap.page_allocator.free(buf);
        return result;
    }

    /// Import from a buffer. Returns the number of entries imported.
    pub fn importData(self: *Database, data: []const u8, format: options.ExportFormat) !usize {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;
        var pos: usize = 0;
        const ConstReader = struct {
            d: []const u8,
            p: *usize,
            pub fn readAll(r: @This(), out: []u8) !usize {
                const remaining = r.d.len - r.p.*;
                const n = @min(out.len, remaining);
                @memcpy(out[0..n], r.d[r.p.*..][0..n]);
                r.p.* += n;
                return n;
            }
            pub fn readByte(r: @This()) !u8 {
                if (r.p.* >= r.d.len) return error.EndOfStream;
                const byte = r.d[r.p.*];
                r.p.* += 1;
                return byte;
            }
            pub fn readInt(r: @This(), comptime T: type, endian: std.builtin.Endian) !T {
                var int_buf: [@sizeOf(T)]u8 = undefined;
                const n = try r.readAll(&int_buf);
                if (n < @sizeOf(T)) return error.EndOfStream;
                return std.mem.readInt(T, &int_buf, endian);
            }
            pub fn readUntilDelimiter(r: @This(), delim_buf: []u8, delimiter: u8) ![]u8 {
                var idx: usize = 0;
                while (idx < delim_buf.len) : (idx += 1) {
                    const byte = r.readByte() catch |err| {
                        if (err == error.EndOfStream and idx > 0) return delim_buf[0..idx];
                        return err;
                    };
                    if (byte == delimiter) return delim_buf[0..idx];
                    delim_buf[idx] = byte;
                }
                return error.StreamTooLong;
            }
        };
        return try export_fn.importFrom(&self.tree, ConstReader{ .d = data, .p = &pos }, .{ .format = format });
    }

    pub fn checkpoint(self: *Database) !void {
        if (!self.is_open) return error.DatabaseClosed;
        try self.wal.truncate();
    }

    pub fn compact(self: *Database) !void {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;
        try self.wal.truncate();
    }

    pub fn ttlRemaining(self: *Database, key: []const u8) ?i64 {
        if (!self.is_open) return null;
        const expires_at = self.ttls.get(key) orelse return null;
        if (self.current_time_ms >= expires_at) return 0;
        return @intCast(expires_at - self.current_time_ms);
    }

    pub fn purgeExpired(self: *Database) !usize {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;
        var purged: usize = 0;
        var expired_keys = std.ArrayList([]const u8).empty;
        defer expired_keys.deinit(self.allocator);

        var iter = self.ttls.iterator();
        while (iter.next()) |entry| {
            if (self.current_time_ms >= entry.value_ptr.*) {
                try expired_keys.append(self.allocator, entry.key_ptr.*);
            }
        }
        for (expired_keys.items) |key| {
            if (try self.tree.delete(key)) {
                _ = self.ttls.remove(key);
                purged += 1;
            }
        }
        return purged;
    }

    pub fn setTime(self: *Database, time_ms: u64) void {
        self.current_time_ms = time_ms;
    }

    pub fn collection(self: *Database, name: []const u8) Collection {
        self.collection_names.put(name, {}) catch {};
        return .{ .db = self, .name = name };
    }

    pub fn collections(self: *Database) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).empty;
        var iter = self.collection_names.keyIterator();
        while (iter.next()) |key_ptr| {
            try result.append(self.allocator, key_ptr.*);
        }
        return result;
    }

    pub fn hasCollection(self: *Database, name: []const u8) bool {
        return self.collection_names.get(name) != null;
    }

    pub fn deleteCollection(self: *Database, name: []const u8) !bool {
        if (!self.is_open) return error.DatabaseClosed;
        if (self.db_options.read_only) return error.ReadOnlyDatabase;
        if (!self.hasCollection(name)) return false;

        var buf: [2048]u8 = undefined;
        const prefix = std.fmt.bufPrint(&buf, "{s}:", .{name}) catch return false;
        _ = try self.deletePrefix(prefix);
        _ = self.collection_names.remove(name);
        return true;
    }

    pub fn info(self: *Database) DatabaseInfo {
        return .{
            .entries = self.count(),
            .size = self.estimateSize(),
            .collection_count = @intCast(self.collection_names.count()),
            .format_version = serialize.FILE_VERSION,
            .is_open = self.is_open,
        };
    }

    pub fn getStats(self: *Database) StatsInfo {
        return .{
            .reads = self.stats.getReads(),
            .writes = self.stats.getWrites(),
            .deletes = self.stats.getDeletes(),
            .hits = self.stats.getHits(),
            .misses = self.stats.getMisses(),
        };
    }

    pub fn resetStats(self: *Database) void {
        self.stats.reset();
    }

    fn prefixedKey(self: *Database, collection_name: []const u8, key: []const u8, buf: []u8) ?[]const u8 {
        _ = self;
        const prefix_len = collection_name.len + 1;
        if (prefix_len + key.len > buf.len) return null;
        @memcpy(buf[0..collection_name.len], collection_name);
        buf[collection_name.len] = ':';
        @memcpy(buf[prefix_len..][0..key.len], key);
        return buf[0 .. prefix_len + key.len];
    }

    pub fn batch(self: *Database) Batch {
        return Batch.init(self);
    }
};

pub const DatabaseInfo = struct {
    entries: usize,
    size: usize,
    collection_count: u32,
    format_version: u16,
    is_open: bool,
};

pub const StatsInfo = struct {
    reads: u64,
    writes: u64,
    deletes: u64,
    hits: u64,
    misses: u64,
};

pub const Batch = struct {
    db: *Database,
    ops: std.ArrayList(BatchOp),

    const BatchOp = struct {
        collection: ?[]const u8,
        collection_owned: bool,
        key: []const u8,
        value: ?[]const u8,
    };

    pub fn init(db: *Database) Batch {
        return .{
            .db = db,
            .ops = std.ArrayList(BatchOp).empty,
        };
    }

    pub fn deinit(self: *Batch) void {
        for (self.ops.items) |op| {
            if (op.collection_owned) {
                if (op.collection) |c| self.db.allocator.free(c);
            }
            self.db.allocator.free(op.key);
            if (op.value) |v| self.db.allocator.free(v);
        }
        self.ops.deinit(self.db.allocator);
    }

    pub fn set(self: *Batch, collection: Collection, key: []const u8, value: []const u8) !void {
        const col_copy = try self.db.allocator.dupe(u8, collection.name);
        errdefer self.db.allocator.free(col_copy);
        const key_copy = try self.db.allocator.dupe(u8, key);
        errdefer self.db.allocator.free(key_copy);
        const val_copy = try self.db.allocator.dupe(u8, value);
        errdefer self.db.allocator.free(val_copy);
        try self.ops.append(self.db.allocator, .{
            .collection = col_copy,
            .collection_owned = true,
            .key = key_copy,
            .value = val_copy,
        });
    }

    pub fn delete(self: *Batch, collection: Collection, key: []const u8) !void {
        const col_copy = try self.db.allocator.dupe(u8, collection.name);
        errdefer self.db.allocator.free(col_copy);
        const key_copy = try self.db.allocator.dupe(u8, key);
        errdefer self.db.allocator.free(key_copy);
        try self.ops.append(self.db.allocator, .{
            .collection = col_copy,
            .collection_owned = true,
            .key = key_copy,
            .value = null,
        });
    }

    pub fn clear(self: *Batch, collection: Collection) !void {
        const col_copy = try self.db.allocator.dupe(u8, collection.name);
        errdefer self.db.allocator.free(col_copy);
        try self.ops.append(self.db.allocator, .{
            .collection = col_copy,
            .collection_owned = true,
            .key = "",
            .value = null,
        });
    }

    pub fn commit(self: *Batch) !void {
        for (self.ops.items) |op| {
            if (op.collection) |col_name| {
                if (op.key.len == 0 and op.value == null) {
                    var prefix_buf: [2048]u8 = undefined;
                    const prefix = std.fmt.bufPrint(&prefix_buf, "{s}:", .{col_name}) catch continue;
                    _ = try self.db.deletePrefix(prefix);
                } else {
                    var buf: [2048]u8 = undefined;
                    const full_key = self.db.prefixedKey(col_name, op.key, &buf) orelse return error.KeyTooLarge;
                    if (op.value) |v| {
                        try self.db.put(full_key, v);
                    } else {
                        try self.db.delete(full_key);
                    }
                }
            } else {
                if (op.value) |v| {
                    try self.db.put(op.key, v);
                } else {
                    try self.db.delete(op.key);
                }
            }
            if (op.collection_owned) {
                if (op.collection) |c| self.db.allocator.free(c);
            }
            self.db.allocator.free(op.key);
            if (op.value) |v| self.db.allocator.free(v);
        }
        self.ops.clearRetainingCapacity();
    }

    pub fn rollback(self: *Batch) void {
        self.deinit();
        self.ops = std.ArrayList(BatchOp).empty;
    }
};

pub const Collection = struct {
    db: *Database,
    name: []const u8,

    fn prefixedKey(self: Collection, key: []const u8, buf: []u8) ?[]const u8 {
        const prefix_len = self.name.len + 1;
        if (prefix_len + key.len > buf.len) return null;
        @memcpy(buf[0..self.name.len], self.name);
        buf[self.name.len] = ':';
        @memcpy(buf[prefix_len..][0..key.len], key);
        return buf[0 .. prefix_len + key.len];
    }

    pub fn put(self: Collection, key: []const u8, value: []const u8) !void {
        var buf: [2048]u8 = undefined;
        const full_key = self.prefixedKey(key, &buf) orelse return error.KeyTooLarge;
        try self.db.put(full_key, value);
    }

    pub fn set(self: Collection, key: []const u8, value: []const u8) !void {
        return self.put(key, value);
    }

    pub fn get(self: Collection, key: []const u8) ?[]const u8 {
        var buf: [2048]u8 = undefined;
        const full_key = self.prefixedKey(key, &buf) orelse return null;
        return self.db.get(full_key);
    }

    pub fn delete(self: Collection, key: []const u8) !void {
        var buf: [2048]u8 = undefined;
        const full_key = self.prefixedKey(key, &buf) orelse return error.KeyTooLarge;
        try self.db.delete(full_key);
    }

    pub fn contains(self: Collection, key: []const u8) bool {
        var buf: [2048]u8 = undefined;
        const full_key = self.prefixedKey(key, &buf) orelse return false;
        return self.db.contains(full_key);
    }

    pub fn exists(self: Collection, key: []const u8) bool {
        return self.contains(key);
    }

    pub fn count(self: Collection) usize {
        var buf: [2048]u8 = undefined;
        const col_prefix = std.fmt.bufPrint(&buf, "{s}:", .{self.name}) catch return 0;
        return self.db.countPrefix(col_prefix);
    }

    pub fn isEmpty(self: Collection) bool {
        return self.count() == 0;
    }

    pub fn size(self: Collection) usize {
        var total: usize = 0;
        var buf: [2048]u8 = undefined;
        const col_prefix = std.fmt.bufPrint(&buf, "{s}:", .{self.name}) catch return 0;
        for (self.db.tree.keys.items, self.db.tree.values.items) |key, val| {
            if (std.mem.startsWith(u8, key, col_prefix)) {
                total += key.len + val.len;
            }
        }
        return total;
    }

    pub fn clear(self: Collection) !usize {
        var buf: [2048]u8 = undefined;
        const col_prefix = std.fmt.bufPrint(&buf, "{s}:", .{self.name}) catch return 0;
        return self.db.deletePrefix(col_prefix);
    }

    pub fn first(self: Collection) ?Entry {
        var iter = self.iterator(null, null);
        return iter.next();
    }

    pub fn last(self: Collection) ?Entry {
        var buf: [2048]u8 = undefined;
        const col_prefix = std.fmt.bufPrint(&buf, "{s}:", .{self.name}) catch return null;
        var result: ?Entry = null;
        var iter = self.db.tree.iterator(col_prefix, null);
        while (iter.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key, col_prefix)) {
                result = Entry{ .key = entry.key[col_prefix.len..], .value = entry.value };
            } else break;
        }
        return result;
    }

    pub fn entries(self: Collection) std.ArrayList(Entry) {
        var buf: [2048]u8 = undefined;
        const col_prefix = std.fmt.bufPrint(&buf, "{s}:", .{self.name}) catch return std.ArrayList(Entry).empty;
        return self.db.search(.{ .prefix = col_prefix }) catch std.ArrayList(Entry).empty;
    }

    pub fn keys(self: Collection) std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).empty;
        var buf: [2048]u8 = undefined;
        const col_prefix = std.fmt.bufPrint(&buf, "{s}:", .{self.name}) catch return result;
        for (self.db.tree.keys.items) |key| {
            if (std.mem.startsWith(u8, key, col_prefix)) {
                result.append(self.db.allocator, key[col_prefix.len..]) catch break;
            }
        }
        return result;
    }

    pub fn values(self: Collection) std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).empty;
        var buf: [2048]u8 = undefined;
        const col_prefix = std.fmt.bufPrint(&buf, "{s}:", .{self.name}) catch return result;
        for (self.db.tree.keys.items, self.db.tree.values.items) |key, val| {
            if (std.mem.startsWith(u8, key, col_prefix)) {
                result.append(self.db.allocator, val) catch break;
            }
        }
        return result;
    }

    pub fn iterator(self: Collection, from: ?[]const u8, to: ?[]const u8) CollectionIterator {
        var from_buf: [2048]u8 = undefined;
        var to_buf: [2048]u8 = undefined;
        var prefix_buf: [2048]u8 = undefined;
        const col_prefix = std.fmt.bufPrint(&prefix_buf, "{s}:", .{self.name}) catch return .{ .inner = null, .prefix_len = 0 };
        const full_from = if (from) |f| self.prefixedKey(f, &from_buf) else col_prefix;
        const full_to = if (to) |t| self.prefixedKey(t, &to_buf) else null;
        return .{
            .inner = self.db.iterator(full_from, full_to),
            .prefix_len = self.name.len + 1,
        };
    }

    pub fn reverseIterator(self: Collection) CollectionReverseIterator {
        var all = self.entries();
        var reversed = std.ArrayList(Entry).empty;
        var i = all.items.len;
        while (i > 0) {
            i -= 1;
            reversed.append(self.db.allocator, all.items[i]) catch break;
        }
        all.deinit(self.db.allocator);
        return .{ .entries = reversed, .pos = 0 };
    }

    pub fn prefix(self: Collection, prefix_str: []const u8) CollectionIterator {
        var buf: [2048]u8 = undefined;
        const full_prefix = std.fmt.bufPrint(&buf, "{s}:{s}", .{ self.name, prefix_str }) catch return .{ .inner = null, .prefix_len = 0 };
        return .{
            .inner = self.db.iterator(full_prefix, null),
            .prefix_len = self.name.len + 1,
        };
    }

    pub fn deletePrefix(self: Collection, prefix_str: []const u8) !usize {
        var buf: [2048]u8 = undefined;
        const full_prefix = std.fmt.bufPrint(&buf, "{s}:{s}", .{ self.name, prefix_str }) catch return 0;
        return self.db.deletePrefix(full_prefix);
    }

    pub fn countPrefix(self: Collection, prefix_str: []const u8) usize {
        var buf: [2048]u8 = undefined;
        const full_prefix = std.fmt.bufPrint(&buf, "{s}:{s}", .{ self.name, prefix_str }) catch return 0;
        return self.db.countPrefix(full_prefix);
    }

    pub fn range(self: Collection, from: []const u8, to: []const u8) std.ArrayList(Entry) {
        var result = std.ArrayList(Entry).empty;
        var from_buf: [2048]u8 = undefined;
        var to_buf: [2048]u8 = undefined;
        const full_from = self.prefixedKey(from, &from_buf) orelse return result;
        const full_to = self.prefixedKey(to, &to_buf) orelse return result;
        var iter = self.db.tree.iterator(full_from, full_to);
        while (iter.next()) |entry| {
            result.append(self.db.allocator, Entry{
                .key = entry.key[self.name.len + 1 ..],
                .value = entry.value,
            }) catch break;
        }
        return result;
    }
};

pub const CollectionIterator = struct {
    inner: ?btree.BTree.Iterator,
    prefix_len: usize,

    pub fn next(self: *CollectionIterator) ?Entry {
        if (self.inner) |*it| {
            if (it.next()) |entry| {
                return Entry{
                    .key = entry.key[self.prefix_len..],
                    .value = entry.value,
                };
            }
        }
        return null;
    }
};

pub const CollectionReverseIterator = struct {
    entries: std.ArrayList(Entry),
    pos: usize,

    pub fn next(self: *CollectionReverseIterator) ?Entry {
        if (self.pos >= self.entries.items.len) return null;
        const entry = self.entries.items[self.pos];
        self.pos += 1;
        return entry;
    }

    pub fn deinit(self: *CollectionReverseIterator, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
    }
};

test "Database open and close" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();
    try std.testing.expect(db.is_open);
}

test "Database CRUD" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("name", "Alice");
    try db.put("age", "30");

    try std.testing.expectEqualStrings("Alice", db.get("name").?);
    try std.testing.expectEqualStrings("30", db.get("age").?);
    try std.testing.expect(db.contains("name"));
    try std.testing.expect(!db.contains("missing"));

    try std.testing.expectEqual(@as(usize, 2), db.count());

    try db.delete("age");
    try std.testing.expect(!db.contains("age"));
    try std.testing.expectEqual(@as(usize, 1), db.count());
}

test "Database update replaces value" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key", "old");
    try db.put("key", "new");

    try std.testing.expectEqualStrings("new", db.get("key").?);
    try std.testing.expectEqual(@as(usize, 1), db.count());
}

test "Database transaction commit" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    var txn = try db.begin(false);
    try txn.put("key1", "value1");
    try db.commitTransaction(&txn);

    try std.testing.expectEqualStrings("value1", db.get("key1").?);
}

test "Database transaction convenience" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    var txn = try db.transaction();
    try txn.put("key1", "value1");
    try db.commitTransaction(&txn);

    try std.testing.expectEqualStrings("value1", db.get("key1").?);
}

test "Database readTransaction" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key", "value");
    var txn = try db.readTransaction();
    defer txn.deinit();

    try std.testing.expect(txn.read_only);
    try std.testing.expect(!txn.is_active or txn.read_only);
}

test "Batch commit with collections" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    const products = db.collection("products");

    var batch = db.batch();
    defer batch.deinit();

    try batch.set(users, "1:name", "Alice");
    try batch.set(users, "2:name", "Bob");
    try batch.set(products, "widget:price", "29.99");
    try batch.commit();

    try std.testing.expectEqualStrings("Alice", users.get("1:name").?);
    try std.testing.expectEqualStrings("Bob", users.get("2:name").?);
    try std.testing.expectEqualStrings("29.99", products.get("widget:price").?);
}

test "Batch delete with collections" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    try users.set("1:name", "Alice");
    try users.set("2:name", "Bob");

    var batch = db.batch();
    defer batch.deinit();
    try batch.delete(users, "1:name");
    try batch.commit();

    try std.testing.expect(users.get("1:name") == null);
    try std.testing.expectEqualStrings("Bob", users.get("2:name").?);
}

test "Batch clear with collections" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    const products = db.collection("products");
    try users.set("1:name", "Alice");
    try products.set("widget:price", "29.99");

    var batch = db.batch();
    defer batch.deinit();
    try batch.clear(users);
    try batch.commit();

    try std.testing.expectEqual(@as(usize, 0), users.count());
    try std.testing.expectEqual(@as(usize, 1), products.count());
}

test "Batch rollback discards ops" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    var batch = db.batch();
    try batch.set(users, "1:name", "Alice");
    batch.rollback();

    try std.testing.expectEqual(@as(usize, 0), db.count());
}

test "Batch deinit without commit" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    {
        var batch = db.batch();
        try batch.set(users, "1:name", "Alice");
        batch.deinit();
    }

    try std.testing.expectEqual(@as(usize, 0), db.count());
}

test "Database delete prefix" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("user:1:name", "Alice");
    try db.put("user:1:age", "30");
    try db.put("user:2:name", "Bob");
    try db.put("post:1:title", "Hello");

    const deleted = try db.deletePrefix("user:");
    try std.testing.expectEqual(@as(usize, 3), deleted);
    try std.testing.expectEqual(@as(usize, 1), db.count());
}

test "Database count prefix" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("user:1", "Alice");
    try db.put("user:2", "Bob");
    try db.put("post:1", "Hello");

    try std.testing.expectEqual(@as(usize, 2), db.countPrefix("user:"));
    try std.testing.expectEqual(@as(usize, 1), db.countPrefix("post:"));
    try std.testing.expectEqual(@as(usize, 0), db.countPrefix("comment:"));
}

test "Database clear" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key1", "val1");
    try db.put("key2", "val2");
    try std.testing.expectEqual(@as(usize, 2), db.count());

    try db.clear();
    try std.testing.expectEqual(@as(usize, 0), db.count());
}

test "Database iterator" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("a", "1");
    try db.put("b", "2");
    try db.put("c", "3");
    try db.put("d", "4");

    var iter = db.iterator("b", "d").?;
    var count: usize = 0;
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "Database read-only" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{ .read_only = true });
    defer db.close();

    const result = db.put("key", "value");
    try std.testing.expectError(error.ReadOnlyDatabase, result);
}

test "Database closed errors" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    db.close();

    try std.testing.expectError(error.DatabaseClosed, db.put("k", "v"));
    try std.testing.expect(db.get("k") == null);
}

test "Collection set and get" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    try users.set("1:name", "Alice");
    try users.set("2:name", "Bob");

    try std.testing.expectEqualStrings("Alice", users.get("1:name").?);
    try std.testing.expectEqualStrings("Bob", users.get("2:name").?);
    try std.testing.expectEqual(@as(usize, 2), users.count());
}

test "Collection delete and clear" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.put("a", "1");
    try items.put("b", "2");
    try items.put("c", "3");

    try items.delete("b");
    try std.testing.expectEqual(@as(usize, 2), items.count());

    const cleared = try items.clear();
    try std.testing.expectEqual(@as(usize, 2), cleared);
    try std.testing.expectEqual(@as(usize, 0), items.count());
}

test "Collection isolation" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    const posts = db.collection("posts");

    try users.put("1", "Alice");
    try posts.put("1", "Hello");

    try std.testing.expectEqualStrings("Alice", users.get("1").?);
    try std.testing.expectEqualStrings("Hello", posts.get("1").?);
    try std.testing.expectEqual(@as(usize, 1), users.count());
    try std.testing.expectEqual(@as(usize, 1), posts.count());
}

test "Collection set overwrites" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("key", "value1");
    try items.set("key", "value2");
    try std.testing.expectEqualStrings("value2", items.get("key").?);
    try std.testing.expectEqual(@as(usize, 1), items.count());
}

test "Collection isEmpty" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try std.testing.expect(items.isEmpty());
    try items.set("k", "v");
    try std.testing.expect(!items.isEmpty());
}

test "Collection first and last" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("a", "1");
    try items.set("b", "2");
    try items.set("c", "3");

    const first = items.first().?;
    try std.testing.expectEqualStrings("1", first.value);

    const last = items.last().?;
    try std.testing.expectEqualStrings("3", last.value);
}

test "Collection first and last empty" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try std.testing.expect(items.first() == null);
    try std.testing.expect(items.last() == null);
}

test "Collection keys and values" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("a", "1");
    try items.set("b", "2");

    var keys = items.keys();
    defer keys.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), keys.items.len);

    var vals = items.values();
    defer vals.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), vals.items.len);
}

test "Collection entries" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("a", "1");
    try items.set("b", "2");

    var ents = items.entries();
    defer ents.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), ents.items.len);
}

test "Collection iterator" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    try users.set("1", "Alice");
    try users.set("2", "Bob");
    try users.set("3", "Charlie");

    var iter = users.iterator(null, null);
    var count: usize = 0;
    while (iter.next()) |entry| {
        count += 1;
        try std.testing.expect(entry.key.len > 0);
    }
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "Collection reverse iterator" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    try users.set("1", "Alice");
    try users.set("2", "Bob");
    try users.set("3", "Charlie");

    var iter = users.reverseIterator();
    defer iter.deinit(allocator);

    const first = iter.next().?;
    try std.testing.expectEqualStrings("Charlie", first.value);
    const second = iter.next().?;
    try std.testing.expectEqualStrings("Bob", second.value);
    const third = iter.next().?;
    try std.testing.expectEqualStrings("Alice", third.value);
    try std.testing.expect(iter.next() == null);
}

test "Collection range query" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("a", "1");
    try items.set("b", "2");
    try items.set("c", "3");
    try items.set("d", "4");

    var r = items.range("b", "d");
    defer r.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), r.items.len);
    try std.testing.expectEqualStrings("b", r.items[0].key);
    try std.testing.expectEqualStrings("c", r.items[1].key);
}

test "Collection prefix query" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("user:1:name", "Alice");
    try items.set("user:2:name", "Bob");
    try items.set("post:1:title", "Hello");

    var count: usize = 0;
    var iter = items.prefix("user:");
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "Collection countPrefix" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("user:1", "Alice");
    try items.set("user:2", "Bob");
    try items.set("post:1", "Hello");

    try std.testing.expectEqual(@as(usize, 2), items.countPrefix("user:"));
    try std.testing.expectEqual(@as(usize, 1), items.countPrefix("post:"));
}

test "Collection deletePrefix" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("user:1:name", "Alice");
    try items.set("user:2:name", "Bob");
    try items.set("post:1:title", "Hello");

    const deleted = try items.deletePrefix("user:");
    try std.testing.expectEqual(@as(usize, 2), deleted);
    try std.testing.expectEqual(@as(usize, 1), items.count());
}

test "Collection size" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("a", "1");
    try items.set("bb", "22");

    const size = items.size();
    try std.testing.expect(size > 0);
}

test "Multiple collections isolation" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const a = db.collection("a");
    const b = db.collection("b");
    const c = db.collection("c");

    try a.set("k1", "v1");
    try b.set("k1", "v2");
    try c.set("k1", "v3");

    try std.testing.expectEqualStrings("v1", a.get("k1").?);
    try std.testing.expectEqualStrings("v2", b.get("k1").?);
    try std.testing.expectEqualStrings("v3", c.get("k1").?);
}

test "Database hasCollection" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try std.testing.expect(!db.hasCollection("users"));
    _ = db.collection("users");
    try std.testing.expect(db.hasCollection("users"));
}

test "Database collections list" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    _ = db.collection("users");
    _ = db.collection("products");

    var cols = try db.collections();
    defer cols.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), cols.items.len);
}

test "Database deleteCollection" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    try users.set("1:name", "Alice");
    try std.testing.expectEqual(@as(usize, 1), users.count());

    const deleted = try db.deleteCollection("users");
    try std.testing.expect(deleted);
    try std.testing.expect(!db.hasCollection("users"));
    try std.testing.expectEqual(@as(usize, 0), db.count());
}

test "Database deleteCollection nonexistent" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const deleted = try db.deleteCollection("nonexistent");
    try std.testing.expect(!deleted);
}

test "Database info" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const users = db.collection("users");
    try users.set("1:name", "Alice");

    const info = db.info();
    try std.testing.expectEqual(@as(usize, 1), info.entries);
    try std.testing.expect(info.size > 0);
    try std.testing.expect(info.is_open);
}

test "Database getStats and resetStats" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key", "value");
    _ = db.get("key");
    _ = db.get("missing");

    var s = db.getStats();
    try std.testing.expectEqual(@as(u64, 1), s.writes);
    try std.testing.expectEqual(@as(u64, 2), s.reads);
    try std.testing.expectEqual(@as(u64, 1), s.hits);
    try std.testing.expectEqual(@as(u64, 1), s.misses);

    db.resetStats();
    s = db.getStats();
    try std.testing.expectEqual(@as(u64, 0), s.reads);
    try std.testing.expectEqual(@as(u64, 0), s.writes);
}

test "Database checkpoint" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key", "value");
    try db.checkpoint();
    try std.testing.expectEqualStrings("value", db.get("key").?);
}

test "Database compact preserves data" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("k1", "v1");
    try db.compact();
    try std.testing.expectEqual(@as(usize, 1), db.count());
}

test "Database export and import" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key1", "value1");
    try db.put("key2", "value2");

    var buffer: [4096]u8 = undefined;
    var fbs = serialize.FixedBufferStream.init(&buffer);
    try db.exportTo(fbs.writer(), .{ .format = .raw_snapshot });

    var db2 = try Database.open(allocator, .{});
    defer db2.close();

    fbs.pos = 0;
    const imported = try db2.importFrom(fbs.reader(), .{ .format = .raw_snapshot });
    try std.testing.expectEqual(@as(usize, 2), imported);

    try std.testing.expectEqualStrings("value1", db2.get("key1").?);
    try std.testing.expectEqualStrings("value2", db2.get("key2").?);
}

test "Database TTL" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    db.setTime(0);
    try db.putTTL("key1", "value1", 1000);

    try std.testing.expectEqualStrings("value1", db.get("key1").?);

    db.setTime(500);
    try std.testing.expectEqualStrings("value1", db.get("key1").?);

    db.setTime(1000);
    try std.testing.expect(db.get("key1") == null);
}

test "Transaction delete and commit" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key", "value");

    var txn = try db.begin(false);
    try txn.delete("key");
    try db.commitTransaction(&txn);

    try std.testing.expect(db.get("key") == null);
}

test "Transaction rollback preserves data" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key", "original");

    var txn = try db.begin(false);
    try txn.put("key", "modified");
    try db.rollbackTransaction(&txn);

    try std.testing.expectEqualStrings("original", db.get("key").?);
}

test "Transaction read-only prevents write" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    var txn = try db.begin(true);
    defer txn.deinit();

    const result = txn.put("key", "value");
    try std.testing.expectError(error.TransactionConflict, result);
}

test "Key with colon separator" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("my:collection");
    try items.set("key", "value");
    try std.testing.expectEqualStrings("value", items.get("key").?);
}

test "Empty value" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key", "");
    const result = db.get("key").?;
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "Large value" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    var large_value: [10000]u8 = undefined;
    for (&large_value, 0..) |*b, i| b.* = @intCast(i % 256);

    try db.put("key", &large_value);
    const result = db.get("key").?;
    try std.testing.expectEqual(@as(usize, 10000), result.len);
}

test "Unicode UTF-8 values" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("greeting", "Hello, World!");
    try db.put("emoji", "\xf0\x9f\x91\x8b");
    try std.testing.expectEqualStrings("Hello, World!", db.get("greeting").?);
    try std.testing.expectEqualStrings("\xf0\x9f\x91\x8b", db.get("emoji").?);
}

test "Special characters in keys" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    try db.put("key with spaces", "value1");
    try db.put("key/with/slashes", "value2");
    try std.testing.expectEqualStrings("value1", db.get("key with spaces").?);
    try std.testing.expectEqualStrings("value2", db.get("key/with/slashes").?);
}

test "BTree sorted order" {
    const allocator = std.testing.allocator;
    var tree = btree.BTree.init(allocator, 4);
    defer tree.deinit();

    try tree.insert("c", "3");
    try tree.insert("a", "1");
    try tree.insert("d", "4");
    try tree.insert("b", "2");

    var all = tree.getAll();
    defer all.deinit(allocator);

    try std.testing.expectEqualStrings("a", all.items[0].key);
    try std.testing.expectEqualStrings("b", all.items[1].key);
    try std.testing.expectEqualStrings("c", all.items[2].key);
    try std.testing.expectEqualStrings("d", all.items[3].key);
}

test "BTree delete prefix" {
    const allocator = std.testing.allocator;
    var tree = btree.BTree.init(allocator, 4);
    defer tree.deinit();

    try tree.insert("user:1", "Alice");
    try tree.insert("user:2", "Bob");
    try tree.insert("post:1", "Hello");

    const deleted = try tree.deletePrefix("user:");
    try std.testing.expectEqual(@as(usize, 2), deleted);
    try std.testing.expectEqual(@as(usize, 1), tree.count());
}

test "Collection empty operations" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try std.testing.expect(items.get("nonexistent") == null);
    try items.delete("nonexistent");
    const cleared = try items.clear();
    try std.testing.expectEqual(@as(usize, 0), cleared);

    var keys = items.keys();
    defer keys.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), keys.items.len);

    var vals = items.values();
    defer vals.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), vals.items.len);
}

test "Collection iterator range" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("a", "1");
    try items.set("b", "2");
    try items.set("c", "3");
    try items.set("d", "4");

    var iter = items.iterator("b", "d");
    var count: usize = 0;
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "Collection range no matches" {
    const allocator = std.testing.allocator;
    var db = try Database.open(allocator, .{});
    defer db.close();

    const items = db.collection("items");
    try items.set("a", "1");

    var r = items.range("x", "z");
    defer r.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), r.items.len);
}

test "Default compression is none" {
    const default_opts = Options{};
    try std.testing.expectEqual(options.Compression.none, default_opts.compression);
}
