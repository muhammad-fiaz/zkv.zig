# Examples

Working code examples demonstrating every feature of zkv.zig. Each example is self contained and can be compiled directly.

## Examples

| Example | Description |
|---------|-------------|
| [Basic CRUD](./basic-crud) | Set, get, delete, exists, count, prefix iteration, and empty values |
| [Transactions](./transactions) | Begin, commit, rollback, view, and update with atomic writes |
| [Batch Operations](./batch-operations) | Batch set/delete/clear with collections and rollback |
| [Backup and Restore](./backup-restore) | First class backup/restore for lossless database copies |
| [Export JSONL](./export-jsonl) | Export database to JSONL format |
| [Export CSV](./export-csv) | Export database to CSV format |
| [Snapshot](./snapshot) | In memory point in time snapshots |
| [Export and Import](./export-import) | Overview of backup, restore, JSONL, CSV, and snapshots |
| [Query Operations](./query-operations) | Search, filter, sorted entries, find, and iterators |
| [Collections](./collections) | Named collections, isolation, entries, keys, values, and clear |
| [Update Operations](./update-operations) | Update specific keys, batch updates, transactions, and delete |
| [Open and Close](./open-close) | Database lifecycle, in memory behavior, and read only mode |
| [Compression](./compression) | None, zstd, brotli, gzip compression with auto detect |
| [Statistics](./statistics) | Track reads, writes, hits, misses, and database info |
| [Value States](./value-states) | Missing, empty, and value semantics with transitions |
