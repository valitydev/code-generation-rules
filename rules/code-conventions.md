# Code conventions

## Architecture and dependencies

- Transport adapters handle protocol concerns only: they validate the transport
  contract, delegate to a service, and translate failures into protocol errors.
- Services implement business scenarios, define the order of operations, and own
  transaction boundaries.
- Complex changes to aggregate parts are delegated to focused handlers instead of
  growing a single service class.
- Repositories encapsulate persistence and return database or domain models. They do
  not build transport responses.
- External systems are hidden behind local client or service interfaces; generated
  stubs and retry mechanics do not leak into business code.
- Spring dependencies are provided through constructor injection and stored in
  `final`/`val` fields. Java components use Lombok's `@RequiredArgsConstructor`
  instead of handwritten constructors when no custom initialization is required.
- Code is organized into the `config`, `config.properties`, `resource`,
  `servlet`, `service`, `repository`, `repository.model`, `scheduler`, `client`,
  `client.model`, `converter`, and `extensions` packages.
- Standalone classes and models are placed in separate files.

## DTOs and converters

- External API requests and responses are represented by typed DTOs, without
  `Map<String, Any>`.
- Transport models are converted before reaching repositories. Simple entities may
  use generated persistence models; aggregates use local domain models.
- JSON property names are specified with Jackson annotations, and closed sets of
  values are represented by enums.
- Model conversion is performed by dedicated `@Component` classes implementing
  Spring's `Converter<S, T>`.
- Requests and responses are created by converters.
- Converters map data but do not write to the database or call external systems.
- Optional fields are set only when present. An omitted value and an explicitly
  empty value remain distinct when the API contract distinguishes them.
- Unsupported conversion directions fail explicitly instead of returning `null`.
- Concrete converters are provided through constructor injection.
- Related data for collections is loaded in batches before conversion; converters
  must not introduce N+1 calls.

## Business operations

- Writes that form one business operation run in one transaction.
- Collection equality ignores order when order has no business meaning.
- One operation timestamp is reused for the persisted changes.

## REST-to-gRPC gateways

- Generated REST interfaces define the transport contract. Controllers and resources
  implement them, validate transport concerns, and delegate without duplicating the
  contract or containing business orchestration.
- Orchestration services build typed gRPC requests, invoke generated clients, and use
  dedicated converters for REST-to-Protobuf and Protobuf-to-REST mapping.
- A request or correlation identifier received at the public boundary is propagated to
  every downstream request and included in logs and typed error responses.
- gRPC failures are mapped centrally to the API's declared error model. At minimum,
  invalid input, unauthenticated, forbidden, not found, conflict, throttling, deadline,
  downstream unavailability, and unexpected internal failures remain distinguishable.
- Transport failures never produce an untyped or accidentally empty error response.

## Kotlin style

- Calls to regular functions and methods use positional arguments.
- Named arguments are allowed for constructors and annotations.
- Constants belonging to a single class are placed in its `private companion object`.
- Shared constants are placed in the appropriate `constants/*.kt` file.

## Configuration

- External integrations are replaced with mock or stub beans in tests.
- Settings are grouped into typed `@ConfigurationProperties`.
- Retry policies, backoff, and asynchronous executors are configured centrally and
  injected by name.

## External clients

- The client is responsible for transport, the converter for mapping, and the service
  for the business scenario.
- A client owns its generated stub and applies the configured retry policy in one
  place.
- Missing recipients or input for an optional side effect causes an early return
  without an external call.
- Asynchronous entry points catch and log failures that cannot be returned to the
  caller.

## Errors and logging

- Expected domain failures use specific exception types and are mapped to transport
  statuses at the transport boundary.
- Logs use parameterized placeholders instead of string concatenation and include
  available request and domain identifiers.
- Large payloads and user content are logged only at `DEBUG` or `TRACE`.
- Transport adapters log request boundaries; services and handlers log business
  steps without duplicating the full payload.

## Testing

- Pure converters and external-client orchestration are covered by unit tests,
  including optional values, empty collections, invalid input, retries, and early
  returns.
- External calls use mocks or stubs and assert the generated request as well as the
  returned result.
- Asynchronous tests wait for an observable event instead of using a fixed `sleep`.
