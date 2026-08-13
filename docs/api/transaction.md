# Transaction API

The `Transaction` struct provides ACID transactions for the database.

## Creating a Transaction

```zig
// Write transaction
var txn = try db.transaction();

// Read only transaction
var txn = try db.readTransaction();
defer txn.deinit();
```

## Transaction Operations

```zig
// Put
try txn.put("key", "value");

// Get
if (txn.get("key")) |val| {
    // use val
}

// Delete
try txn.delete("key");
```

## Committing and Rolling Back

```zig
// Commit
try db.commitTransaction(&txn);

// Rollback
try db.rollbackTransaction(&txn);
```

## Convenience Methods

### view() — Auto Rollback Read

```zig
const result = try db.view(null, ?[]const u8, &(struct {
    fn f(_: void, txn: *zkv.mvcc.Transaction) ?[]const u8 {
        return txn.get("account:alice:balance");
    }
}.f));
```

### update() — Auto Commit Write

```zig
try db.update(null, void, &(struct {
    fn f(_: void, txn: *zkv.mvcc.Transaction) void {
        txn.put("account:alice:balance", "1100") catch return;
        txn.put("account:bob:balance", "700") catch return;
    }
}.f));
```

> [!TIP]
> Prefer `view()` and `update()` over manual transaction management. They handle commit and rollback automatically.

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `read_only` | `bool` | Whether transaction is read only |
| `is_active` | `bool` | Whether transaction is still active |
| `write_set` | `ArrayList(Entry)` | Pending writes |
| `read_set` | `ArrayList([]const u8)` | Keys read in this transaction |

## Error Handling

Transactions return errors for:

> [!CAUTION]
> Writing in a read only transaction will return an error. Always use write transactions for mutations.

- Writing in a read only transaction
- Operating on an inactive (committed/rolled back) transaction
- Memory allocation failures
