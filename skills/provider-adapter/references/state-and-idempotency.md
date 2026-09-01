# State, polling, callbacks, and idempotency

Use for multi-step flows, continuation state, polling, callbacks, or replay handling.

## Continuation state

Use the repository's established state storage and serialization path. Some flows need
state in a deeper continuation scope than others; choose the deepest scope that
reliably survives every step of the concrete scenario rather than imposing one
universal storage location.

Have one obvious serializer/decoder for continuation state. Missing state may create a
new context when the protocol defines that behavior; malformed state should fail
deterministically rather than being silently interpreted as a new operation.

Before changing serialized context, inspect states produced by the previous deployed
version. Add a compatibility test when old state can survive a deployment.

## Polling

Persist enough metadata to continue safely after restart when the surrounding
framework does not already own it. Polling must have a finite deadline/termination
condition and use the existing retry/backoff mechanism rather than tight-looping.

Keep timeout distinct from provider failure and malformed response. Verify both
creation and status-query behavior when the operation is asynchronous and uses both.

## Callbacks

Keep callback models limited to fields the adapter consumes, plus fields required for
validation, security, or correlation.

Preserve the adapter's established asynchronous trigger. Adding optional polling must
not silently remove callback handling unless the intended flow explicitly switches
from one mechanism to the other.

Parse callbacks using the provider's real content type and parameter names rather than
a convenient local representation.

Treat callback delivery as at-least-once unless the provider contract proves
otherwise. A replay must be safe: completed state should not be overwritten and a side
effect should not be emitted twice.

When a provider callback is only a notification, correlate the internal transaction
and obtain the authoritative status through the provider's status operation instead
of trusting an unverified callback status. If the provider contract explicitly makes
the callback authoritative, follow that contract instead.

Receiving a callback signature is not the same as verifying it. Do not claim signature
validation unless the algorithm, secret/key handling, verification behavior, and tests
exist.

When idempotency depends on persistence or a business key, enforce it at a layer that
survives concurrent requests; an in-memory guard is insufficient.
