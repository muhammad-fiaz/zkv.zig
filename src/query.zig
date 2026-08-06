const std = @import("std");
const btree = @import("btree.zig");
const options = @import("options.zig");

pub fn search(tree: *btree.BTree, search_options: options.SearchOptions, allocator: std.mem.Allocator) !std.ArrayList(btree.Entry) {
    var results = std.ArrayList(btree.Entry).empty;

    if (search_options.prefix) |prefix| {
        for (tree.keys.items, tree.values.items) |key, value| {
            if (std.mem.startsWith(u8, key, prefix)) {
                try results.append(allocator, .{ .key = key, .value = value });
            }
        }
    }

    if (search_options.limit) |limit| {
        while (results.items.len > limit) {
            _ = results.pop();
        }
    }

    return results;
}

pub fn filter(tree: *btree.BTree, context: anytype, predicate: fn (@TypeOf(context), btree.Entry) bool, filter_options: options.FilterOptions, allocator: std.mem.Allocator) !std.ArrayList(btree.Entry) {
    var results = std.ArrayList(btree.Entry).empty;

    for (tree.keys.items, tree.values.items) |key, value| {
        const entry = btree.Entry{ .key = key, .value = value };
        if (predicate(context, entry)) {
            try results.append(allocator, entry);
            if (filter_options.limit) |limit| {
                if (results.items.len >= limit) break;
            }
        }
    }

    return results;
}

pub fn sortedEntries(tree: *btree.BTree, context: anytype, comparator: fn (@TypeOf(context), btree.Entry, btree.Entry) std.math.Order, sort_options: options.SortOptions, allocator: std.mem.Allocator) !std.ArrayList(btree.Entry) {
    var results = std.ArrayList(btree.Entry).empty;

    for (tree.keys.items, tree.values.items) |key, value| {
        try results.append(allocator, .{ .key = key, .value = value });
    }

    std.sort.pdq(btree.Entry, results.items, context, struct {
        fn lessThan(_: @TypeOf(context), a: btree.Entry, b: btree.Entry) bool {
            return @intFromEnum(comparator(context, a, b)) == @intFromEnum(std.math.Order.lt);
        }
    }.lessThan);

    if (sort_options.limit) |limit| {
        while (results.items.len > limit) {
            _ = results.pop();
        }
    }

    return results;
}
