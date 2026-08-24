# Adapter conventions

These rules extend the common rules for services that integrate with external
providers.

## Architecture and flow

- Transport entry points validate the transport contract and delegate to services.
- Services coordinate the integration scenario; step-specific behavior is placed in
  focused handlers selected by an explicit state or operation type.
- State transitions and transport intents are built centrally instead of being
  assembled independently by handlers.
- Provider request and response models, converters, constants, and error handling
  stay behind the provider client boundary.

## Configuration and clients

- Runtime configuration keys, provider method names, URL paths, statuses, and error
  codes are declared centrally as constants or enums.
- Per-operation runtime options are validated by a dedicated validator before a
  converter or handler accesses them as non-null values.
- Provider calls use the application's configured `RestClient` and `ObjectMapper`.
- Base URLs, environment selection, request paths, and authorization headers are
  resolved centrally.
- Provider requests and responses use typed DTOs. Internal configuration and helper
  fields that are not part of the wire contract are excluded from serialization.
- An empty response body or a body that cannot be parsed is handled explicitly and
  mapped to a stable integration error.
- HTTP status errors, provider errors, and response parsing errors are distinguished
  before being mapped to domain failures.

## Secrets and logging

- Provider credentials and tokens are obtained through the configured secret service,
  such as Vault. They are never hardcoded or included in logs.
- Kotlin files use a file-level `private val log = KotlinLogging.logger {}` and lazy
  logging blocks.
- PANs, phone numbers, bank accounts, tokens, and other sensitive fields are masked
  before logging or storing diagnostic metadata.
- External request, response, and callback payloads pass through the shared log
  sanitizer before being logged.
- DTOs containing sensitive values provide a safe `toString()` or are never logged as
  complete objects.

## State and polling

- Multi-step operation state is held in a dedicated context. Store it in the deepest
  continuation scope that reliably survives every step of the specific scenario and
  reuse the established serialization path for that scope.
- Missing continuation state creates a new context; malformed state fails explicitly.
- Serialized context changes are backward compatible with states produced by the
  previous deployed version and are covered by compatibility tests.
- Polling metadata, including the deadline and next interval, is stored with the
  operation state.
- Polling is bounded by a deadline. Pending and unknown non-final statuses schedule
  the next attempt using the configured backoff instead of looping immediately.
- Final success, final failure, timeout, transport failure, and malformed provider
  responses produce distinct, deterministic outcomes.
- Callback handlers dispatch by an explicit callback type and are idempotent. A
  repeated callback must not overwrite completed state or repeat a side effect.

## Testing

- Provider HTTP integration tests use WireMock with the application context and real
  client serialization.
- Every provider method covers success, provider failure, HTTP failure, empty body,
  malformed body, and required-field validation where applicable.
- Stateful flows cover pending-to-success, pending-to-failure, polling timeout, and
  callback replay.
- Retry exhaustion and duplicate side effects are covered where the corresponding
  behavior exists.
- Tests assert outbound method, path, headers, and body as well as the mapped result.
- Shared flow fixtures and builders contain transport mechanics; test cases describe
  scenario-specific mocks, actions, and assertions.
- New provider scenarios and tests start from the closest existing template or flow
  fixture, reuse established mechanics, and keep provider-specific changes minimal.
