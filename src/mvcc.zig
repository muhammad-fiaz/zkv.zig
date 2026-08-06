const std = @import("std");
const options = @import("options.zig");

pub const Transaction = struct {
    allocator: std.mem.Allocator,
    id: u64,
    read_only: bool,
    is_active: bool,
    read_set: std.ArrayList([]const u8),
    write_set: std.ArrayList(WriteEntry),

    pub const WriteEntry = struct {
        key: []const u8,
        value: ?[]const u8,
    };

    pub fn init(allocator: std.mem.Allocator, id: u64, read_only: bool) Transaction {
        return Transaction{
            .allocator = allocator,
            .id = id,
            .read_only = read_only,
            .is_active = true,
            .read_set = std.ArrayList([]const u8).empty,
            .write_set = std.ArrayList(WriteEntry).empty,
        };
    }

    pub fn deinit(self: *Transaction) void {
        for (self.read_set.items) |key| self.allocator.free(key);
        self.read_set.deinit(self.allocator);
        for (self.write_set.items) |entry| {
            self.allocator.free(entry.key);
            if (entry.value) |v| self.allocator.free(v);
        }
        self.write_set.deinit(self.allocator);
    }

    pub fn put(self: *Transaction, key: []const u8, value: []const u8) !void {
        if (self.read_only) return error.TransactionConflict;
        try self.write_set.append(self.allocator, .{
            .key = try self.allocator.dupe(u8, key),
            .value = try self.allocator.dupe(u8, value),
        });
    }

    pub fn set(self: *Transaction, key: []const u8, value: []const u8) !void {
        return self.put(key, value);
    }

    pub fn delete(self: *Transaction, key: []const u8) !void {
        if (self.read_only) return error.TransactionConflict;
        try self.write_set.append(self.allocator, .{
            .key = try self.allocator.dupe(u8, key),
            .value = null,
        });
    }

    pub fn get(self: *Transaction, key: []const u8) ?[]const u8 {
        var i = self.write_set.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.write_set.items[i].key, key)) {
                return self.write_set.items[i].value;
            }
        }
        return null;
    }

    pub fn contains(self: *Transaction, key: []const u8) bool {
        return self.get(key) != null;
    }

    pub fn commit(self: *Transaction) !void {
        self.is_active = false;
    }

    pub fn rollback(self: *Transaction) !void {
        self.is_active = false;
    }
};

pub const Mvcc = struct {
    allocator: std.mem.Allocator,
    next_id: u64,

    pub fn init(allocator: std.mem.Allocator) Mvcc {
        return .{
            .allocator = allocator,
            .next_id = 1,
        };
    }

    pub fn begin(self: *Mvcc, read_only: bool) !Transaction {
        const id = self.next_id;
        self.next_id += 1;
        return Transaction.init(self.allocator, id, read_only);
    }
};

test "Transaction put and commit" {
    const allocator = std.testing.allocator;
    const mvcc = Mvcc.init(allocator);
    _ = mvcc;

    var txn = Transaction.init(allocator, 1, false);
    defer txn.deinit();

    try txn.put("key1", "value1");
    try std.testing.expectEqual(@as(usize, 1), txn.write_set.items.len);

    try txn.commit();
    try std.testing.expect(!txn.is_active);
}

test "Transaction read-only" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, true);
    defer txn.deinit();

    const result = txn.put("key1", "value1");
    try std.testing.expectError(error.TransactionConflict, result);
}

test "Transaction set is alias for put" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, false);
    defer txn.deinit();

    try txn.set("key1", "value1");
    try std.testing.expectEqual(@as(usize, 1), txn.write_set.items.len);
    try std.testing.expectEqualStrings("value1", txn.get("key1").?);
}

test "Transaction get from write set" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, false);
    defer txn.deinit();

    try txn.put("key1", "value1");
    try txn.put("key2", "value2");

    try std.testing.expectEqualStrings("value1", txn.get("key1").?);
    try std.testing.expectEqualStrings("value2", txn.get("key2").?);
    try std.testing.expect(txn.get("missing") == null);
}

test "Transaction contains" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, false);
    defer txn.deinit();

    try txn.put("key1", "value1");
    try std.testing.expect(txn.contains("key1"));
    try std.testing.expect(!txn.contains("missing"));
}

test "Transaction delete" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, false);
    defer txn.deinit();

    try txn.put("key1", "value1");
    try txn.delete("key1");

    try std.testing.expect(txn.get("key1") == null);
    try std.testing.expect(!txn.contains("key1"));
}

test "Transaction read-only delete fails" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, true);
    defer txn.deinit();

    const result = txn.delete("key1");
    try std.testing.expectError(error.TransactionConflict, result);
}

test "Transaction multiple puts" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, false);
    defer txn.deinit();

    try txn.put("k1", "v1");
    try txn.put("k2", "v2");
    try txn.put("k3", "v3");

    try std.testing.expectEqual(@as(usize, 3), txn.write_set.items.len);
}

test "Transaction commit sets inactive" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, false);
    defer txn.deinit();

    try txn.put("key", "value");
    try txn.commit();
    try std.testing.expect(!txn.is_active);
}

test "Transaction rollback sets inactive" {
    const allocator = std.testing.allocator;
    var txn = Transaction.init(allocator, 1, false);
    defer txn.deinit();

    try txn.put("key", "value");
    try txn.rollback();
    try std.testing.expect(!txn.is_active);
}

test "Mvcc begin increments id" {
    const allocator = std.testing.allocator;
    var mvcc = Mvcc.init(allocator);

    var txn1 = try mvcc.begin(false);
    defer txn1.deinit();
    var txn2 = try mvcc.begin(true);
    defer txn2.deinit();

    try std.testing.expect(txn1.id != txn2.id);
}
