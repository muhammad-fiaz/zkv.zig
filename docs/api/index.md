# API Overview

zkv.zig is an embedded key value database written in Zig. It provides a simple, fast API for storing and retrieving key value pairs with support for TTL, transactions, compression, batch operations, and collections.

## Quick Reference

### Database Lifecycle

| Method | Description |
|--------|-------------|
| `Database.open(allocator, options)` | Open or create a database |
| `db.close()` | Close the database |
| `db.collection(name)` | Get a named collection |
| `db.batch()` | Create a batch for bulk operations |
| `db.info()` | Get database info (entries, size, collections) |
| `db.getStats()` | Get operation statistics |
| `db.resetStats()` | Reset statistics counters |
| `db.checkpoint()` | Flush WAL to main database |
| `db.compact()` | Reclaim free space |
| `db.estimateSize()` | Estimate in memory size |
| `db.exportData(format)` | Export to buffer (raw/jsonl/csv) |
| `db.importData(data, format)` | Import from buffer |

### Collection Operations

| Method | Description |
|--------|-------------|
| `collection.set(key, value)` | Insert or update a key value pair |
| `collection.get(key)` | Retrieve a value by key (returns `?[]const u8`) |
| `collection.delete(key)` | Remove a key value pair |
| `collection.exists(key)` | Check if a key exists |
| `collection.count()` | Get number of entries in collection |
| `collection.clear()` | Remove all entries in collection |
| `collection.isEmpty()` | Check if collection has no entries |
| `collection.size()` | Estimate collection size in bytes |
| `collection.entries()` | Get all key value pairs |
| `collection.keys()` | Get all keys |
| `collection.values()` | Get all values |
| `collection.first()` | Get first entry |
| `collection.last()` | Get last entry |
| `collection.iterator(from, to)` | Iterate over key ranges |
| `collection.reverseIterator()` | Iterate in reverse order |
| `collection.prefix(str)` | Iterate over prefix matches |
| `collection.deletePrefix(str)` | Delete all entries with prefix |
| `collection.countPrefix(str)` | Count entries with prefix |
| `collection.range(from, to)` | Get entries in a key range |

### Batch Operations

| Method | Description |
|--------|-------------|
| `batch.set(collection, key, value)` | Queue a set operation |
| `batch.delete(collection, key)` | Queue a delete operation |
| `batch.clear(collection)` | Queue a clear operation |
| `batch.commit()` | Execute all queued operations |
| `batch.rollback()` | Discard all queued operations |
| `batch.deinit()` | Free batch resources |

### Transactions

| Method | Description |
|--------|-------------|
| `db.begin(read_only)` | Start a transaction |
| `db.transaction()` | Convenience: begin write transaction |
| `db.readTransaction()` | Convenience: begin read only transaction |
| `db.commitTransaction(&txn)` | Commit and apply transaction |
| `db.rollbackTransaction(&txn)` | Rollback transaction |
| `db.view(context, T, func)` | Auto rollback read transaction |
| `db.update(context, T, func)` | Auto commit write transaction |

> [!TIP]
> Use `db.view()` and `db.update()` for automatic transaction management. They handle commit and rollback automatically.

### Query Operations

| Method | Description |
|--------|-------------|
| `db.search(options)` | Search by prefix |
| `db.filter(context, predicate, options)` | Filter entries by predicate |
| `db.find(context, predicate)` | Find first matching entry |
| `db.findAndReplace(context, predicate, new_value)` | Replace matching values |
| `db.sortedEntries(context, comparator, options)` | Sort entries by custom comparator |
| `db.iterator(from, to)` | Range iterator |

### Export/Import

| Method | Description |
|--------|-------------|
| `db.exportTo(writer, options)` | Export to writer (raw/jsonl/csv) |
| `db.importFrom(reader, options)` | Import from reader |
| `db.exportData(format)` | Export to allocated buffer |
| `db.importData(data, format)` | Import from buffer |
| `db.getSnapshot()` | Get all entries as ArrayList |

### TTL Operations

| Method | Description |
|--------|-------------|
| `db.putTTL(key, value, ttl_ms)` | Insert with time to live in milliseconds |
| `db.ttlRemaining(key)` | Get remaining TTL in ms, or null |
| `db.purgeExpired()` | Remove expired entries, return count |
| `db.setTime(time_ms)` | Set the logical clock |

> [!NOTE]
> TTL values are in milliseconds. Use `db.purgeExpired()` periodically to clean up expired entries.

### Collection Management

| Method | Description |
|--------|-------------|
| `db.collections()` | List all collection names |
| `db.hasCollection(name)` | Check if collection exists |
| `db.deleteCollection(name)` | Delete a collection and all its entries |

## Types

| Type | Description |
|------|-------------|
| `Database` | Main database handle |
| `Collection` | Named subset of entries |
| `Batch` | Bulk operation queue |
| `Transaction` | ACID transaction |
| `Options` | Database configuration |
| `Entry` | Key value pair struct |
| `DatabaseInfo` | Database metadata |
| `StatsInfo` | Operation statistics |
