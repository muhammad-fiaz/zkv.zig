const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zstd_dep = b.dependency("zstd", .{
        .target = target,
        .optimize = optimize,
    });

    const brotli_dep = b.dependency("brotli", .{
        .target = target,
        .optimize = optimize,
    });

    const zkv_module = b.addModule("zkv", .{
        .root_source_file = b.path("src/zkv.zig"),
    });
    zkv_module.addImport("zstd", zstd_dep.module("zstd"));
    zkv_module.addImport("brotli", brotli_dep.module("brotli"));

    const lib_root_module = b.createModule(.{
        .root_source_file = b.path("src/zkv.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_root_module.addImport("zstd", zstd_dep.module("zstd"));
    lib_root_module.addImport("brotli", brotli_dep.module("brotli"));

    const lib = b.addLibrary(.{
        .name = "zkv",
        .linkage = .static,
        .root_module = lib_root_module,
    });
    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zkv.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("zstd", zstd_dep.module("zstd"));
    tests.root_module.addImport("brotli", brotli_dep.module("brotli"));

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    if (target.result.os.tag == builtin.os.tag and target.result.cpu.arch == builtin.cpu.arch) {
        test_step.dependOn(&run_tests.step);
    } else {
        const install_tests = b.addInstallArtifact(tests, .{});
        test_step.dependOn(&install_tests.step);
    }

    // Docs
    const docs_step = b.step("docs", "Generate library documentation");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    // Examples
    const examples = [_]struct { name: []const u8, file: []const u8 }{
        .{ .name = "basic_crud", .file = "examples/basic_crud.zig" },
        .{ .name = "transactions", .file = "examples/transactions.zig" },
        .{ .name = "batch_operations", .file = "examples/batch_operations.zig" },
        .{ .name = "export_import", .file = "examples/export_import.zig" },
        .{ .name = "backup_restore", .file = "examples/backup_restore.zig" },
        .{ .name = "export_jsonl", .file = "examples/export_jsonl.zig" },
        .{ .name = "export_csv", .file = "examples/export_csv.zig" },
        .{ .name = "snapshot", .file = "examples/snapshot.zig" },
        .{ .name = "query_operations", .file = "examples/query_operations.zig" },
        .{ .name = "open_close", .file = "examples/open_close.zig" },
        .{ .name = "update_operations", .file = "examples/update_operations.zig" },
        .{ .name = "compression", .file = "examples/compression.zig" },
        .{ .name = "statistics", .file = "examples/statistics.zig" },
        .{ .name = "collections", .file = "examples/collections.zig" },
        .{ .name = "value_states", .file = "examples/value_states.zig" },
    };

    const run_all = b.step("run-all-examples", "Run all examples");
    const is_native = target.result.os.tag == builtin.os.tag and target.result.cpu.arch == builtin.cpu.arch;

    inline for (examples) |ex| {
        const exe_mod = b.createModule(.{
            .root_source_file = b.path(ex.file),
            .target = target,
            .optimize = optimize,
        });
        exe_mod.addImport("zkv", zkv_module);

        const exe = b.addExecutable(.{
            .name = ex.name,
            .root_module = exe_mod,
        });

        const run = b.addRunArtifact(exe);
        run.setCwd(b.path("."));

        const step_name = b.fmt("run-{s}", .{ex.name});
        const step_desc = b.fmt("Run {s} example", .{ex.name});
        const step = b.step(step_name, step_desc);

        if (is_native) {
            step.dependOn(&run.step);
            run_all.dependOn(&run.step);
        } else {
            const install = b.addInstallArtifact(exe, .{});
            step.dependOn(&install.step);
        }
    }
}
