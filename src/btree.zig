const std = @import("std");

pub const Entry = struct {
    key: []const u8,
    value: []const u8,
};

pub const BTree = struct {
    allocator: std.mem.Allocator,
    keys: std.ArrayList([]const u8),
    values: std.ArrayList([]const u8),
    order: usize,

    pub fn init(allocator: std.mem.Allocator, order: usize) BTree {
        return BTree{
            .allocator = allocator,
            .keys = std.ArrayList([]const u8).empty,
            .values = std.ArrayList([]const u8).empty,
            .order = order,
        };
    }

    pub fn deinit(self: *BTree) void {
        for (self.keys.items) |key| self.allocator.free(key);
        for (self.values.items) |val| self.allocator.free(val);
        self.keys.deinit(self.allocator);
        self.values.deinit(self.allocator);
    }

    pub fn insert(self: *BTree, key: []const u8, value: []const u8) !void {
        const idx = self.findIndex(key);

        if (idx < self.keys.items.len and std.mem.eql(u8, self.keys.items[idx], key)) {
            self.allocator.free(self.values.items[idx]);
            self.values.items[idx] = try self.allocator.dupe(u8, value);
            return;
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const val_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(val_copy);

        try self.keys.insert(self.allocator, idx, key_copy);
        try self.values.insert(self.allocator, idx, val_copy);
    }

    pub fn lookup(self: *BTree, key: []const u8) ?[]const u8 {
        const idx = self.findIndex(key);
        if (idx < self.keys.items.len and std.mem.eql(u8, self.keys.items[idx], key)) {
            return self.values.items[idx];
        }
        return null;
    }

    pub fn delete(self: *BTree, key: []const u8) !bool {
        const idx = self.findIndex(key);
        if (idx < self.keys.items.len and std.mem.eql(u8, self.keys.items[idx], key)) {
            self.allocator.free(self.keys.items[idx]);
            self.allocator.free(self.values.items[idx]);
            _ = self.keys.orderedRemove(idx);
            _ = self.values.orderedRemove(idx);
            return true;
        }
        return false;
    }

    pub fn deletePrefix(self: *BTree, prefix: []const u8) !usize {
        var deleted: usize = 0;
        var i: usize = self.keys.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.startsWith(u8, self.keys.items[i], prefix)) {
                self.allocator.free(self.keys.items[i]);
                self.allocator.free(self.values.items[i]);
                _ = self.keys.orderedRemove(i);
                _ = self.values.orderedRemove(i);
                deleted += 1;
            }
        }
        return deleted;
    }

    pub fn countPrefix(self: *BTree, prefix: []const u8) usize {
        var total: usize = 0;
        const start_idx = self.findIndex(prefix);
        var i = start_idx;
        while (i < self.keys.items.len) {
            if (std.mem.startsWith(u8, self.keys.items[i], prefix)) {
                total += 1;
                i += 1;
            } else {
                break;
            }
        }
        return total;
    }

    pub fn contains(self: *BTree, key: []const u8) bool {
        return self.lookup(key) != null;
    }

    pub fn count(self: *BTree) usize {
        return self.keys.items.len;
    }

    pub fn clear(self: *BTree) void {
        for (self.keys.items) |key| self.allocator.free(key);
        for (self.values.items) |val| self.allocator.free(val);
        self.keys.clearRetainingCapacity();
        self.values.clearRetainingCapacity();
    }

    pub fn getAll(self: *BTree) std.ArrayList(Entry) {
        var entries = std.ArrayList(Entry).empty;
        for (self.keys.items, self.values.items) |k, v| {
            entries.append(self.allocator, Entry{ .key = k, .value = v }) catch break;
        }
        return entries;
    }

    pub fn rangeScan(self: *BTree, from: ?[]const u8, to: ?[]const u8) std.ArrayList(Entry) {
        var results = std.ArrayList(Entry).empty;
        for (self.keys.items, self.values.items) |key, value| {
            if (from) |f| {
                if (std.mem.order(u8, key, f) == .lt) continue;
            }
            if (to) |t| {
                if (std.mem.order(u8, key, t) != .lt) break;
            }
            results.append(self.allocator, Entry{ .key = key, .value = value }) catch break;
        }
        return results;
    }

    pub fn iterator(self: *BTree, from: ?[]const u8, to: ?[]const u8) Iterator {
        const start = if (from) |f| self.findIndex(f) else 0;
        const end = if (to) |t| self.findIndex(t) else self.keys.items.len;
        return .{
            .keys = self.keys.items,
            .values = self.values.items,
            .pos = start,
            .end = end,
        };
    }

    fn findIndex(self: *BTree, key: []const u8) usize {
        var low: usize = 0;
        var high: usize = self.keys.items.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            switch (std.mem.order(u8, self.keys.items[mid], key)) {
                .lt => low = mid + 1,
                .gt => high = mid,
                .eq => return mid,
            }
        }
        return low;
    }

    pub const Iterator = struct {
        keys: []const []const u8,
        values: []const []const u8,
        pos: usize,
        end: usize,

        pub fn next(self: *Iterator) ?Entry {
            if (self.pos >= self.end) return null;
            const key = self.keys[self.pos];
            const value = self.values[self.pos];
            self.pos += 1;
            return Entry{ .key = key, .value = value };
        }

        pub fn peek(self: *const Iterator) ?Entry {
            if (self.pos >= self.end) return null;
            return Entry{ .key = self.keys[self.pos], .value = self.values[self.pos] };
        }

        pub fn remaining(self: *const Iterator) usize {
            if (self.pos >= self.end) return 0;
            return self.end - self.pos;
        }

        pub fn reset(self: *Iterator, from: ?[]const u8, to: ?[]const u8) void {
            self.pos = if (from) |f| blk: {
                var low: usize = 0;
                var high: usize = self.keys.len;
                while (low < high) {
                    const mid = low + (high - low) / 2;
                    switch (std.mem.order(u8, self.keys[mid], f)) {
                        .lt => low = mid + 1,
                        .gt => high = mid,
                        .eq => {
                            low = mid;
                            break;
                        },
                    }
                }
                break :blk low;
            } else 0;

            self.end = if (to) |t| blk: {
                var low: usize = 0;
                var high: usize = self.keys.len;
                while (low < high) {
                    const mid = low + (high - low) / 2;
                    switch (std.mem.order(u8, self.keys[mid], t)) {
                        .lt => low = mid + 1,
                        .gt => high = mid,
                        .eq => {
                            low = mid;
                            break;
                        },
                    }
                }
                break :blk low;
            } else self.keys.len;
        }
    };
};

test "BTree insert and lookup" {
    const allocator = std.testing.allocator;
    var tree = BTree.init(allocator, 4);
    defer tree.deinit();

    try tree.insert("key1", "value1");
    try tree.insert("key2", "value2");
    try tree.insert("key3", "value3");

    try std.testing.expectEqualStrings("value1", tree.lookup("key1").?);
    try std.testing.expectEqualStrings("value2", tree.lookup("key2").?);
    try std.testing.expectEqualStrings("value3", tree.lookup("key3").?);
    try std.testing.expectEqual(@as(?[]const u8, null), tree.lookup("key4"));
}

test "BTree update" {
    const allocator = std.testing.allocator;
    var tree = BTree.init(allocator, 4);
    defer tree.deinit();

    try tree.insert("key1", "value1");
    try tree.insert("key1", "updated");

    try std.testing.expectEqualStrings("updated", tree.lookup("key1").?);
    try std.testing.expectEqual(@as(usize, 1), tree.count());
}

test "BTree delete" {
    const allocator = std.testing.allocator;
    var tree = BTree.init(allocator, 4);
    defer tree.deinit();

    try tree.insert("key1", "value1");
    try tree.insert("key2", "value2");

    try std.testing.expect(try tree.delete("key1"));
    try std.testing.expectEqual(@as(?[]const u8, null), tree.lookup("key1"));
    try std.testing.expectEqualStrings("value2", tree.lookup("key2").?);
    try std.testing.expect(!try tree.delete("key999"));
}

test "BTree range scan" {
    const allocator = std.testing.allocator;
    var tree = BTree.init(allocator, 4);
    defer tree.deinit();

    try tree.insert("a", "1");
    try tree.insert("b", "2");
    try tree.insert("c", "3");
    try tree.insert("d", "4");

    var results = tree.rangeScan("b", "d");
    defer results.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), results.items.len);
    try std.testing.expectEqualStrings("2", results.items[0].value);
    try std.testing.expectEqualStrings("3", results.items[1].value);
}
