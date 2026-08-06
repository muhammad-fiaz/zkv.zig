const std = @import("std");
const btree = @import("btree.zig");
const serialize = @import("serialize.zig");
const options = @import("options.zig");

pub fn exportTo(tree: *btree.BTree, writer: anytype, export_options: options.ExportOptions) !void {
    switch (export_options.format) {
        .raw_snapshot => {
            try serialize.writeMagic(writer);
            try serialize.writeFileVersion(writer);
            try serialize.writeU64(writer, @intCast(tree.count()));
            for (tree.keys.items, tree.values.items) |key, value| {
                try serialize.writeLengthPrefixed(writer, key);
                try serialize.writeLengthPrefixed(writer, value);
            }
        },
        .jsonl => {
            for (tree.keys.items, tree.values.items) |key, value| {
                try writer.writeAll("{\"key\":\"");
                try writeEscapedJson(writer, key);
                try writer.writeAll("\",\"value\":\"");
                try writeEscapedJson(writer, value);
                try writer.writeAll("\"}\n");
            }
        },
        .csv => {
            try writer.writeAll("key,value\n");
            for (tree.keys.items, tree.values.items) |key, value| {
                try writer.writeAll("\"");
                try writeEscapedCsv(writer, key);
                try writer.writeAll("\",\"");
                try writeEscapedCsv(writer, value);
                try writer.writeAll("\"\n");
            }
        },
    }
}

fn writeEscapedJson(writer: anytype, data: []const u8) !void {
    for (data) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(byte),
        }
    }
}

fn writeEscapedCsv(writer: anytype, data: []const u8) !void {
    for (data) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\"\""),
            else => try writer.writeByte(byte),
        }
    }
}

pub fn importFrom(tree: *btree.BTree, reader: anytype, import_options: options.ImportOptions) !usize {
    var count: usize = 0;

    switch (import_options.format) {
        .raw_snapshot => {
            try serialize.readMagic(reader);
            _ = try serialize.readFileVersion(reader);
            const entry_count = try serialize.readU64(reader);
            for (0..entry_count) |_| {
                const key = try serialize.readLengthPrefixedAlloc(reader, tree.allocator);
                defer tree.allocator.free(key);

                const val = try serialize.readLengthPrefixedAlloc(reader, tree.allocator);
                defer tree.allocator.free(val);

                try tree.insert(key, val);
                count += 1;
            }
        },
        .jsonl => {
            var buffer: [4096]u8 = undefined;
            while (true) {
                const line = reader.readUntilDelimiter(&buffer, '\n') catch |err| {
                    if (err == error.EndOfStream) break;
                    return err;
                };
                if (line.len == 0) continue;

                var parsed = try std.json.parseFromSlice(struct {
                    key: []const u8,
                    value: []const u8,
                }, std.heap.page_allocator, line, .{});
                defer parsed.deinit();

                try tree.insert(parsed.value.key, parsed.value.value);
                count += 1;
            }
        },
        .csv => {
            var buffer: [4096]u8 = undefined;
            _ = reader.readUntilDelimiter(&buffer, '\n') catch |err| {
                if (err == error.EndOfStream) return 0;
                return err;
            };

            while (true) {
                const line = reader.readUntilDelimiter(&buffer, '\n') catch |err| {
                    if (err == error.EndOfStream) break;
                    return err;
                };
                if (line.len == 0) continue;

                var iter = std.mem.splitScalar(u8, line, ',');
                const key_str = iter.next() orelse continue;
                const value_str = iter.next() orelse continue;

                try tree.insert(key_str, value_str);
                count += 1;
            }
        },
    }
    return count;
}
