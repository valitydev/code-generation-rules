---
name: provider-adapter
description: Implement or modify an external payment/provider adapter, including provider clients, callbacks, polling, continuation state, error mapping, or adapter integration tests. Do not use for ordinary internal service changes that do not cross a provider boundary.
---

# Provider adapter

Use different sources of truth for different questions:

- the provider's current API specification and supplied documentation define the
  external request/response/authentication/callback contract;
- the target repository's current code, tests, build configuration, and local
  instructions define its architecture, flow mechanics, and verification conventions.

Existing adapters, templates, fixtures, and tests are implementation evidence and
starting points, not proof of the current provider contract.

## Invariants

Keep these when they apply to the concrete flow:

- send and consume only provider fields required by the current contract or actually
  needed by the adapter flow; do not forward optional upstream data merely because a
  template exposes it;
- preserve functionally required correlation/callback data even when the provider
  schema marks it optional;
- repeated callbacks must not repeat a completed side effect or overwrite final state;
- polling must be bounded and use the repository's configured retry/backoff mechanism;
- continuation/state changes must remain readable across deployment when state can
  survive a version change, unless the task explicitly coordinates a migration;
- credentials, tokens, PANs, account identifiers, and other sensitive values must not
  leak through source code, logs, exceptions, DTO string rendering, or diagnostics;
- transport failures, provider-declared failures, malformed responses, timeout, and
  final business outcomes must not collapse accidentally into one ambiguous path.

## Load additional guidance only when relevant

- provider request/response DTOs, serialization, client errors, or sensitive logging →
  `references/provider-boundary.md`;
- callback, polling, replay, or multi-step continuation state →
  `references/state-and-idempotency.md`;
- new adapter work or substantial adaptation of a previous-provider template →
  `references/template-adaptation.md`;
- before finalizing a provider behavior change → `references/testing.md`;
- OpenAPI contract changes → `../../references/openapi.md`;
- Protobuf/generated contract changes → `../../references/code-generation.md`;
- persistence/schema changes → `../../references/database.md`.

## Workflow

1. Identify the operation and map the provider surface the adapter actually uses:
   request, response, authentication, status polling, callbacks, and error responses as
   applicable. Distinguish schema-required fields from fields that are functionally
   required by the local flow.
2. Find the nearest production adapter(s) and map the local boundaries: transport entry
   point, scenario/service, provider client, state/context, error mapping, and tests.
3. Read only the references that match the concrete change.
4. Implement the smallest contract-backed change that preserves the local architecture.
   Access optional/union-based upstream data only when the provider request needs it,
   handle absence explicitly, and do not invent defaults without accepted domain
   meaning.
5. Run focused tests plus the repository's existing formatter, linter, generator, and
   compatibility checks for touched code. Confirm that the intended suites actually ran.
6. When the task permits a safe provider sandbox/probe and credentials are available,
   verify the material request/response behavior against the real provider as described
   in `references/testing.md`. Otherwise do not claim real-provider proof.
7. Review the final diff for unintended removal of callback, polling, correlation,
   error, or state behavior. If repository evidence conflicts with this skill on a
   non-safety architectural preference, follow the repository and record the
   discrepancy rather than rewriting the project toward a generic template.

## What not to encode here

Package names, Spring annotations, specific converter interfaces, logging libraries,
and DTO layout are implementation choices unless the target repository already
standardizes them. Consult `../../references/code-conventions.md` only when the task
needs an architectural decision not settled by local code.
