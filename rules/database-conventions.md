# Database conventions

## Stack and migrations

- Migrations are run by Flyway from `src/main/resources/db/migration`.
- Every schema change is introduced by a new immutable migration; an applied
  migration is never rewritten.
- Migration names follow `V<version>__<short_description>.sql` and describe the
  schema or index changes they contain.
- `IF NOT EXISTS` is used for supported PostgreSQL objects.

## Schema design and data lifecycle

- Primary keys, constraints, and indexes are defined explicitly and
  given meaningful names.
- Storage invariants use database defaults and `NOT NULL` constraints and are also
  represented consistently in converters and repositories.
- When designing, priority is given to soft-delete.

## jOOQ and repositories

- Flyway runs before jOOQ code generation.
- Generated classes are created in `target/generated-sources/jooq`.
- Generated tables, records, POJOs, and enums are used.
- Flyway and ShedLock tables are excluded from jOOQ code generation.
- When a schema change affects application data, update every affected layer in the
  same change: the migration, generated jOOQ model, input conversion, write query,
  read model, output conversion, and tests.
- Repositories use `DSLContext` and keep jOOQ queries out of services and transport
  resources.
- Inserts populate the complete model and map it to a generated record. Updates set
  only fields that the operation is allowed to change.
- Query aliases match read-model property names when results are mapped with
  `fetchInto`.
- Empty collections are handled before `IN` queries and collection writes.
- Upsert is used only with a defined business key. Conflict columns and the minimal
  set of updated columns are listed explicitly.
- Related data for result collections is fetched in batches to avoid N+1 queries.
- Type-safe jOOQ DSL is preferred. PostgreSQL-specific plain SQL uses bind values or
  `inline(...)`, never string concatenation of user input.
- Absence from a single-row query is represented consistently.

## Transaction boundaries

- Transactions are placed at the narrowest layer that can complete the operation
  atomically. Keep a transaction inside one repository method when possible; move
  it to a service only when the operation coordinates several repository calls.
- Transactions contain only the calls required for atomic persistence and do not
  include remote calls or unrelated work.
- Replacing related records and updating the owning aggregate happen in one transaction.

## State transitions

- A state transition, its validation, and all resulting writes run in one transaction.
- Repeating the same transition with the same business data is idempotent. A transition
  that conflicts with an existing final state fails with a specific domain error.
- Business keys are protected by explicit unique constraints. Upsert or conflict
  handling complements domain validation when concurrent requests may race.
- Batch state changes verify that the number of affected rows matches the expected
  number; a partial update fails the transaction.

## Transactional event delivery

- The domain write and insertion of its delivery event are committed in the same
  database transaction. A failure rolls back both.
- Every event has a stable identifier, a deterministic sequence or ordering key, a
  delivery status, an attempt count, and the time at which it became eligible.
- The event payload contains the immutable data required for delivery; a retry does not
  rebuild a materially different event from current mutable state.
- Concurrent workers claim disjoint events with a short transaction, for example by
  using a lease or `FOR UPDATE SKIP LOCKED`. A database row lock is not held while a
  remote call is in flight.
- Delivery is idempotent by event identifier. A worker records success only after the
  recipient accepts the event and safely retries an ambiguous outcome.
- Retries are bounded and use configured backoff and next-attempt time. Exhausted events
  move to an explicit terminal or dead-letter state and remain observable.

## Time

- `TIMESTAMP WITHOUT TIME ZONE` and `LocalDateTime` are used; values are
  interpreted as UTC.
- Insert, update, and upsert operations create their audit timestamps explicitly in
  UTC.
- All writes produced by one business operation reuse the same timestamp so their
  audit and state-change times remain consistent.

## Integration testing

- Test credentials are allowed only for embedded PostgreSQL and Testcontainers.
- Migration, query, filter, search, and transactional changes are tested against a
  real PostgreSQL instance provided by embedded PostgreSQL or Testcontainers.
- Tests clean only the data they own and do not depend on execution order.
- Repository tests assert persisted values, conflict/update behavior, and empty-result
  boundaries, not only affected-row counts.
- CRUD scenarios verify create, read, update, logical deletion, and the values in both
  the database and returned model.
- Filtering and search rules include positive, negative, and boundary cases;
  pagination also covers page boundaries and continuation tokens.
- Stateful-operation tests cover idempotent replay, conflicting final states,
  concurrent requests, affected-row mismatches, and full transactional rollback.
- Event-delivery tests cover atomic domain/event rollback, concurrent workers, ordered
  delivery, duplicate replay, ambiguous responses, process restart, retry backoff, and
  exhaustion of the attempt limit.
