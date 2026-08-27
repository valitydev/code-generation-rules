# Provider adapter verification

Use the smallest relevant subset. Verification depth should follow the behavior and
risk of the changed operation rather than a ceremonial fixed test count.

## Evidence levels

Keep these claims distinct:

1. local model/serialization verification;
2. mocked HTTP/integration-flow verification;
3. real provider contract verification;
4. production callback or end-to-end runtime proof.

Do not present one level as proof of another.

When credentials and a safe provider test environment are available and the task
permits it, probe the same endpoint, headers, serialization, and minimal field set the
production client uses. Real probes must use unique external references, avoid
destructive actions, redact credentials/sensitive values, and report any provider test
objects they create. For asynchronous flows, verify creation and the material status
query; verify callbacks against real provider examples or deliveries when safely
possible.

If a real response is unavailable, specification-derived fixtures are acceptable but
should be identifiable as such rather than presented as captured provider evidence.

## Request and response behavior

For each changed provider operation, consider only cases the contract can actually
produce:

- success;
- pending/status transitions when applicable;
- provider-declared final failure;
- non-2xx response with structured provider error;
- empty, malformed, or incomplete response where relevant;
- missing/invalid required runtime data.

Assert material outbound method/path/headers/body, including required fields being
present and unnecessary optional fields being absent. Also assert the mapped domain
result or failure. A generic assertion that some exception occurred is insufficient
when the provider supplies a structured error that the adapter is expected to
preserve.

Use the repository's established HTTP test mechanism. In Spring/WireMock projects,
prefer real serialization through the application client over mocking the client
itself when wire compatibility is the risk.

## Fixtures and path coverage

Every committed response fixture should be used by a test or explicitly documented as
deferred contract material. Remove duplicate and stale fixtures.

A fixture's presence is not proof that its path is tested. Trace the material scenario
from resource loading through the mock/client, conversion, and final assertion.

Where practical, integration tests should exercise the complete local processing path:
request conversion → HTTP client → response conversion → domain result or mapped
failure.

For a newly added happy-path operation, add the material negative path when the
provider uses a distinct error response or mapping. Do not weaken assertions merely to
make copied template tests pass.

If the adapter change also includes a build/platform migration, follow the target
repository's migration guide and required clean build; successful compilation alone
does not prove that expected tests, generators, or runtime-relevant checks executed.
