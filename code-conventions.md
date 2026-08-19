## Structure and dependencies

- Code is organized into the `config`, `config.properties`, `resource`,
  `servlet`, `service`, `repository`, `repository.model`, `scheduler`, `client`,
  `client.model`, `converter`, and `extensions` packages.
- Standalone classes and models are placed in separate files.

## DTOs and converters

- External API requests and responses are represented by typed DTOs, without
  `Map<String, Any>`.
- JSON property names are specified with Jackson annotations, and closed sets of
  values are represented by enums.
- Model conversion is performed by dedicated `@Component` classes implementing
  Spring's `Converter<S, T>`.
- Requests and responses are created by converters.
- Concrete converters are provided through constructor injection.

## Kotlin style

- Calls to regular functions and methods use positional arguments.
- Named arguments are allowed for constructors and annotations.
- Constants belonging to a single class are placed in its `private companion object`.
- Shared constants are placed in the appropriate `constants/*.kt` file.

## Configuration

- External integrations are replaced with mock or stub beans in tests.
- Settings are grouped into typed `@ConfigurationProperties`.

## External clients

- The client is responsible for transport, the converter for mapping, and the service
  for the business scenario.

Changes are verified with `mvn ktlint:check` and `mvn clean test`.
