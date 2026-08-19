## Stack and migrations

- Migrations are run by Flyway from `src/main/resources/db/migration`.
- `IF NOT EXISTS` is used for supported PostgreSQL objects.
- Primary keys, constraints, foreign keys, and indexes are defined explicitly and
  given meaningful names.
- Flyway and ShedLock tables are excluded from jOOQ code generation.

## jOOQ

- Flyway runs before jOOQ code generation.
- Generated classes are created in `target/generated-sources/jooq`.
- Generated tables, records, and enums are used; generated code is not edited
  manually.
- Repositories use `DSLContext`.

## Time and secrets

- `TIMESTAMP WITHOUT TIME ZONE` and `LocalDateTime` are used; values are
  interpreted as UTC.
- Test credentials are allowed only for embedded PostgreSQL and Testcontainers.

Database changes are verified with Flyway, jOOQ code generation, and repository
integration tests using a PostgreSQL Testcontainer.
