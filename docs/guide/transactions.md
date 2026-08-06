---
title: Transactions
description: Atomic multi-key operations with transactions in zkv.zig.
---

# Transactions

ACID transactions ensure atomicity, consistency, isolation, and durability for multi-key operations.

## Begin a Transaction

```zig
var txn = try db.begin(false); // false = read-write
// or
var txn = try db.begin(true);  // true = read-only
```

## Transaction Operations

```zig
// Read
const val = txn.get("key1");

// Write
try txn.put("key1", "value1");
try txn.put("key2", "value2");

// Delete
try txn.delete("key1");
```

## Commit

Persist all changes atomically:

```zig
try db.commitTransaction(&txn);
```

## Rollback

Discard all changes:

```zig
try db.rollbackTransaction(&txn);
```

## view() - Auto-Rollback Read

Read within a transaction that automatically rolls back:

```zig
const result = try db.view(null, ?[]const u8, &(struct {
    fn f(_: void, t: *zkv.mvcc.Transaction) ?[]const u8 {
        return t.get("account:alice:balance");
    }
}.f));
```

## update() - Auto-Commit Write

Write within a transaction that automatically commits:

```zig
try db.update(null, void, &(struct {
    fn f(_: void, t: *zkv.mvcc.Transaction) void {
        t.put("account:alice:balance", "1100") catch return;
        t.put("account:bob:balance", "700") catch return;
    }
}.f));
```

## Example: Bank Transfer

```zig
var txn = try db.begin(false);
try txn.put("account:alice:balance", "900");
try txn.put("account:bob:balance", "600");
try db.commitTransaction(&txn);
```

## Example: Failed Transfer (Rollback)

```zig
var txn = try db.begin(false);
try txn.put("account:alice:balance", "0");
try db.rollbackTransaction(&txn);
// Alice's balance unchanged
```
