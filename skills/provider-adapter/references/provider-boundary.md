# Provider boundary

Use for provider client, configuration, request/response models, serialization, error
mapping, or sensitive logging work.

## Request contract

- Build the smallest request justified by the provider contract and the local flow.
  Do not read or forward optional upstream fields merely because they exist in Thrift,
  DTOs, unions, or a copied template.
- Access optional objects and union branches only when their value is required. Handle
  absent objects and inactive branches explicitly.
- Do not synthesize defaults unless the provider field is required and the default has
  an accepted domain meaning. Preserve omitted versus explicit empty/default values
  when the provider contract distinguishes them.
- Preserve fields that are functionally required for asynchronous processing or
  correlation, such as callback URLs or external transaction references, even when
  the provider schema marks them optional.
- Keep distinct domain values distinct. Do not place payment links, deeplinks, phone
  numbers, QR payloads, or other values into a different generic field merely because
  a template lacks the right mapping; propagate the correct domain field instead.

## Client and response contract

Keep provider-specific transport details behind one clear boundary. Centralize base
URL/environment selection, authentication, request paths, and serialization according
to the target repository's existing client stack.

Use typed request/response DTOs for stable provider contracts, but model only fields
the adapter consumes unless additional fields are required for validation, security,
correlation, or behavior.

Do not assume successful and error responses have the same shape. Verify how the HTTP
client exposes non-2xx responses before deciding where provider error fields belong.
Error responses may omit normal success fields such as identifiers, statuses,
requisites, or payment data.

Treat empty bodies, malformed bodies, unexpected status codes, and provider-declared
errors explicitly. Preserve the provider's most specific useful error code/message in
the repository's existing domain error model. If several provider fields can supply
that value, define and test an explicit provider-specific priority rather than relying
on incidental deserialization order.

Runtime configuration required for an operation should be validated before business
logic assumes it is present. Every provider call should have a finite timeout. Retries
should be bounded and used only when the repeated operation is safe or protected by
provider/application idempotency.

## Secrets and diagnostics

Obtain credentials from the project's configured secret mechanism. Never hardcode
them.

Sanitize provider request/response/callback data before logging. Review both raw HTTP
logging/sanitizers and structured DTO logging; securing only one path is insufficient.
Do not rely on a default `toString()` for DTOs that may contain credentials, tokens,
PANs, account numbers, phone numbers, personal identifiers, callback signatures,
external references, QR payloads, payment links, or deeplinks.
