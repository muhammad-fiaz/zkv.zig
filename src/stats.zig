const std = @import("std");

pub const Stats = struct {
    reads: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    writes: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    deletes: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    hits: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    misses: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    pub fn init() Stats {
        return .{};
    }

    pub fn incrementReads(self: *Stats) void {
        _ = self.reads.fetchAdd(1, .monotonic);
    }

    pub fn incrementWrites(self: *Stats) void {
        _ = self.writes.fetchAdd(1, .monotonic);
    }

    pub fn incrementDeletes(self: *Stats) void {
        _ = self.deletes.fetchAdd(1, .monotonic);
    }

    pub fn incrementHits(self: *Stats) void {
        _ = self.hits.fetchAdd(1, .monotonic);
    }

    pub fn incrementMisses(self: *Stats) void {
        _ = self.misses.fetchAdd(1, .monotonic);
    }

    pub fn getReads(self: *const Stats) u64 {
        return self.reads.load(.monotonic);
    }

    pub fn getWrites(self: *const Stats) u64 {
        return self.writes.load(.monotonic);
    }

    pub fn getDeletes(self: *const Stats) u64 {
        return self.deletes.load(.monotonic);
    }

    pub fn getHits(self: *const Stats) u64 {
        return self.hits.load(.monotonic);
    }

    pub fn getMisses(self: *const Stats) u64 {
        return self.misses.load(.monotonic);
    }

    pub fn reset(self: *Stats) void {
        self.reads.store(0, .monotonic);
        self.writes.store(0, .monotonic);
        self.deletes.store(0, .monotonic);
        self.hits.store(0, .monotonic);
        self.misses.store(0, .monotonic);
    }
};
