# Database change reference

Read this only for schema, migration, repository, persistence, or transactional-state
work.

This file intentionally separates compatibility/integrity concerns from historical
implementation preferences. Inspect the target repository before choosing a database
style.

## Hard compatibility and integrity checks

- Applied migrations are immutable; introduce a new migration for a schema change.
- Trace a schema change through migration, generated model (if any), write path, read
  path, conversion, and tests.
- Keep database writes that form one business transition in one transaction. Place
  the transaction at the narrowest layer that can complete the transition atomically,
  and do not keep remote calls or unrelated work inside it.
- Protect real business keys against concurrent races with an appropriate database
  constraint and domain handling.
- Do not build SQL by concatenating untrusted values.
- Batch related reads when a collection path would otherwise produce N+1 queries.
- Paginated reads need deterministic ordering with a unique tie-breaker; use the
  repository's established pagination strategy.
- Verify state-changing batch operations when a partial update would violate the
  business transition.
- When a state transition can be replayed, preserve idempotent replay and reject a
  transition that conflicts with an already-final state according to the domain model.

## Transactional event delivery, when present

If the repository uses an outbox or database-backed delivery queue, preserve the
pattern's correctness properties rather than copying one implementation shape:

- commit the domain write and event record atomically;
- keep enough immutable event identity/payload to retry the same logical delivery;
- do not hold a database row lock while a remote call is in flight;
- make duplicate/ambiguous delivery safe through the project's idempotency mechanism;
- keep retries bounded/backed off and exhausted delivery observable.

## Project-specific choices: verify before applying

The following may be valid conventions in existing Vality repositories, but they are
not universal database truths. Preserve them where the target project already relies
on them; do not introduce them into a new architecture merely because they are listed
here:

- Flyway location and migration naming;
- jOOQ generation layout;
- use or absence of foreign keys;
- soft-delete lifecycle;
- `TIMESTAMP WITHOUT TIME ZONE` + `LocalDateTime` interpreted as UTC;
- particular upsert patterns;
- ShedLock/Flyway generator exclusions.

If the task is specifically to define an organization-wide database policy, decide
these points explicitly and enforce deterministic parts with migration/CI tooling
rather than relying only on agent prose.

## Testing

For PostgreSQL-specific behavior, migrations, locking, conflicts, or transaction
semantics, prefer a real PostgreSQL integration test (for example Testcontainers)
over a substitute database.

Cover the failure mode introduced by the change: conflict, rollback, concurrent claim,
idempotent replay, empty result, pagination boundary, or retry exhaustion as
applicable.
