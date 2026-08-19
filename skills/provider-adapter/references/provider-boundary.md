# Provider boundary

Use for provider client, configuration, serialization, error mapping, or sensitive
logging work.

## Client and configuration

Keep provider-specific transport details behind one clear boundary. Centralize base
URL/environment selection, authentication, request paths, and serialization according
to the target repository's existing client stack.

Use typed request/response DTOs for stable provider contracts. Treat empty bodies,
malformed bodies, unexpected status codes, and provider-declared errors explicitly.

Runtime configuration required for an operation should be validated before business
logic assumes it is present.

## Error model

Preserve enough information to distinguish:

- transport/HTTP failure;
- provider-declared rejection/failure;
- response parsing/shape failure;
- retryable/pending outcome;
- final business failure;
- unexpected internal failure.

Map these into the repository's existing domain error model rather than creating a
parallel hierarchy unless necessary.

## Secrets and diagnostics

Obtain credentials from the project's configured secret mechanism. Never hardcode
them.

Sanitize sensitive provider request/response/callback data before logging. Do not rely
on a DTO's default `toString()` when it can expose PANs, tokens, phone numbers, bank
accounts, credentials, or equivalent data.

Use the project's existing sanitizer and logging abstraction when present.
