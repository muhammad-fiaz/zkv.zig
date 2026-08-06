---
title: TTL Operations
description: Set time-to-live on keys and auto-expire data with zkv.zig.
---

# TTL Operations

## Put with TTL

Store a key that expires after a duration (milliseconds):

```zig
// Expires in 5 seconds
try db.putTTL("session:abc", "token123", 5000);
```

## Check Remaining TTL

Get the remaining time-to-live in milliseconds. Returns `?i64`:

```zig
const remaining = db.ttlRemaining("session:abc");
if (remaining) |ms| {
    std.debug.print("Expires in {d}ms\n", .{ms});
} else {
    std.debug.print("No TTL set or key expired\n", .{});
}
```

## Purge Expired Keys

Remove all expired keys and get the count:

```zig
const purged = try db.purgeExpired();
std.debug.print("Removed {d} expired keys\n", .{purged});
```

## Set Custom Time

Override the internal clock (useful for testing):

```zig
db.setTime(1000000); // Set to 1,000,000ms
```

## Example: Session Cache

```zig
// Store sessions with 30-minute expiry
const ttl_ms: u64 = 30 * 60 * 1000;
try db.putTTL("session:user123", "auth_token", ttl_ms);

// Periodically clean up
_ = try db.purgeExpired();
```
