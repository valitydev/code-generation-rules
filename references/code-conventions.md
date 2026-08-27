# Code conventions reference

Use this reference when a task materially changes application architecture, transport
boundaries, conversion, external clients, configuration, or replaces an existing
cross-layer mechanism. It is not part of the always-on prompt.

## First inspect the repository

Before applying any convention below, identify the nearest production implementation
of the same responsibility. Prefer the project's established framework and package
structure when it is coherent.

Do not introduce Spring `Converter`, Lombok, a fixed package taxonomy, a new
handler/service split, or any other abstraction solely because it appears in this
reference.

When replacing or removing a library or mechanism, inventory its material behavior at
the boundary before deleting it. Preserve or intentionally replace required behavior
and verify the behavior that could otherwise disappear behind a successful compile or
a narrower test.

## Durable boundaries

These are useful defaults when the local codebase does not provide stronger evidence:

- Transport resources own protocol validation and protocol error mapping, not business
  orchestration.
- Services coordinate business scenarios. Transaction boundaries belong at the
  narrowest layer that can complete the business transition atomically; do not keep
  remote calls or unrelated work inside a database transaction.
- Persistence access stays behind repositories or an equivalent persistence boundary.
- External systems stay behind local clients/interfaces so generated stubs and retry
  mechanics do not leak into unrelated business code.
- Converters map data; they should not write to the database or perform remote calls.
- Typed DTOs are preferred for stable external contracts over unstructured maps.
- Preserve the distinction between an omitted value and an explicit empty/default
  value whenever the contract gives those states different meaning.
- Collection conversion should not introduce N+1 remote or database calls.
- Request/correlation identifiers should be propagated across transport boundaries
  when the existing system supports them.
- Expected domain failures should remain distinguishable at the transport boundary.

## Configuration and clients

Use the project's existing configuration mechanism. In Spring projects, typed
`@ConfigurationProperties` is generally preferable to scattered string lookups.

Keep transport, mapping, and business-scenario responsibilities separable. Retry,
backoff, authentication, base URL resolution, and serialization should have one
obvious owner rather than being duplicated across handlers.

Every remote call should have a finite timeout. Retries should be bounded and used
only when repeating the operation is safe or protected by an idempotency mechanism.

## Logging

Use the project's logging library and style. Preserve identifiers useful for
diagnostics, but do not log sensitive payloads. Large external payloads should not be
promoted to normal INFO-level logging merely for convenience.

## Testing

Choose the narrowest test that exercises the changed responsibility. Prefer observable
events over fixed sleeps in asynchronous tests. For external clients, assert both the
outbound request and the mapped result when that behavior is part of the change.

A fixture, mock, or test name is not evidence by itself. Confirm that the assertion
observes the material path the system actually uses and that the test would fail for
the regression it is meant to prevent.
