# State, polling, callbacks, and idempotency

Use for multi-step flows, continuation state, polling, callbacks, or replay handling.

## Continuation state

Have one obvious serializer/decoder for continuation state. Missing state may create a
new context when the protocol defines that behavior; malformed state should fail
deterministically rather than being silently interpreted as a new operation.

Before changing a serialized context, inspect examples/states produced by the previous
deployed version. Add a compatibility test when old state can survive a deployment.

## Polling

Persist enough metadata to continue safely after process restart, including deadline
and backoff/next-attempt state when the surrounding framework does not already own it.

Pending or unknown non-final provider statuses should schedule another attempt through
the existing retry mechanism. Do not tight-loop.

Make timeout distinct from provider failure and malformed response.

## Callbacks

Dispatch by an explicit callback/event type when the provider exposes more than one
semantic event.

Treat callback delivery as at-least-once unless the provider contract proves
otherwise. A replay must be safe: completed state should not be overwritten and a
side effect should not be emitted twice.

When idempotency depends on persistence or a business key, enforce it at the layer that
can actually survive concurrent requests; an in-memory guard is insufficient.
