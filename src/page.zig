const std = @import("std");

pub const Entry = struct {
    key: []const u8,
    value: []const u8,
};

pub const EntryList = struct {
    entries: std.ArrayList(Entry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EntryList {
        return .{
            .entries = std.ArrayList(Entry).empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EntryList) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn add(self: *EntryList, key: []const u8, value: []const u8) !void {
        try self.entries.append(self.allocator, .{
            .key = try self.allocator.dupe(u8, key),
            .value = try self.allocator.dupe(u8, value),
        });
    }

    pub fn count(self: EntryList) usize {
        return self.entries.items.len;
    }
};
