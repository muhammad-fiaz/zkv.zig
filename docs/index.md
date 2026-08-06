---
layout: home
title: zkv.zig
titleTemplate: Production-grade embedded key-value database for Zig

hero:
  name: zkv.zig
  text: Embedded Key-Value Database for Zig
  tagline: A super-fast, lightweight embedded key-value database for Zig with ACID transactions, TTL, compression, and more.
  image:
    src: /cover.png
    alt: zkv.zig
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: API Reference
      link: /api/
    - theme: alt
      text: GitHub
      link: https://github.com/muhammad-fiaz/zkv.zig

features:
  - icon: ⚡
    title: High Performance
    details: Sorted-array B-Tree with binary search for O(log n) operations. Zero-copy lookups with in-memory storage.
  - icon: 🔒
    title: ACID Transactions
    details: Full ACID compliance with MVCC snapshot isolation. Begin, commit, and rollback transactions with automatic cleanup.
  - icon: ⏰
    title: TTL Support
    details: Time-to-live for keys with automatic expiration. Purge expired entries on demand or let them expire on read.
  - icon: 🗜️
    title: Compression
    details: Built-in support for zstd, brotli, gzip, lzma, and xz compression. Reduce memory usage for large values.
  - icon: 📦
    title: Batch Operations
    details: Efficient bulk insert and delete operations. Prefix-based deletion and counting for namespace management.
  - icon: 🔍
    details: Search by prefix, filter with custom predicates, sort with custom comparators, and iterate over key ranges.
    title: Rich Query API
  - icon: 📤
    title: Export & Import
    details: Export to raw snapshot, JSONL, or CSV formats. Import from any supported format for data portability.
---
