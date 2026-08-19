---
name: provider-adapter
description: Implement or modify an external payment/provider adapter, including provider clients, callbacks, polling, continuation state, error mapping, or adapter integration tests. Do not use for ordinary internal service changes that do not cross a provider boundary.
---

# Provider adapter

The repository itself is the first specification. Before designing the change, find
the closest existing production adapters and inspect at least one successful analogue
for the same operation type. Prefer established local abstractions when they satisfy
the required semantics.

## Non-negotiable domain behavior

Keep these invariants when they apply to the flow:

- repeated callbacks must not repeat a completed side effect or overwrite final state;
- polling must be bounded by a deadline and use configured backoff rather than an
  immediate unbounded loop;
- continuation/state changes must remain readable by the next deployed version unless
  the task explicitly coordinates a migration;
- credentials, tokens, PANs, account identifiers, and other sensitive values must not
  leak through source code, logs, exceptions, or diagnostic metadata;
- HTTP/transport failures, provider-declared failures, malformed responses, timeout,
  and final business outcomes must not collapse accidentally into one ambiguous path.
- OpenAPI contract changes → `../../references/openapi.md`
- Protobuf/generated contract changes → `../../references/code-generation.md`
- persistence/schema changes → `../../references/database.md`

## Workflow

1. Identify the operation: synchronous request, redirect, polling, callback,
   recurrent operation, refund, payout, or another established flow.
2. Find the nearest existing adapter(s) and map the local boundaries: transport entry
   point, scenario/service, provider client, state/context, error mapping, and tests.
3. Read only the references needed for the task:
   - client/configuration/error/logging work → `references/provider-boundary.md`;
   - callback, polling, or multi-step continuation state →
     `references/state-and-idempotency.md`;
   - before finalizing an adapter behavior change → `references/testing.md`.
4. Implement the smallest change that preserves the local architecture and the domain
   invariants above. Do not refactor unrelated adapters to make them match this skill.
5. Run the project's focused tests plus the existing formatter/linter/generator checks
   for touched code.
6. If repository evidence conflicts with this skill on a non-safety architectural
   preference, follow the repository and record the discrepancy rather than silently
   rewriting the project toward a generic template.

## What not to encode here

Package names, Spring annotations, specific converter interfaces, logging libraries,
and DTO layout are implementation choices unless the target repository already
standardizes them. Consult `../../references/code-conventions.md` only when the task
actually needs an architectural decision not settled by local code.
