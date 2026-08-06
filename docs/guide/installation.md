---
title: Installation
description: How to install and configure zkv.zig in your Zig project.
---

# Installation

## Via zig fetch (recommended)

```bash
zig fetch --save https://github.com/muhammad-fiaz/zkv.zig/archive/refs/tags/0.0.1.tar.gz
```

## Nightly

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zkv.zig
```

## Local Path

Clone the repository:

```bash
git clone https://github.com/muhammad-fiaz/zkv.zig.git
```

Add to `build.zig.zon`:

```zig
.dependencies = .{
    .zkv = .{
        .path = "/path/to/zkv.zig",
    },
},
```

Configure `build.zig`:

```zig
const zkv_dep = b.dependency("zkv", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zkv", zkv_dep.module("zkv"));
```

## Requirements

- Zig 0.16+
- External dependencies: zstd, brotli (bundled via zig-cache)
