# Provider adapter test matrix

Use the smallest relevant subset; do not generate a ceremonial test suite when the
provider operation cannot produce a listed case.

## Client/contract behavior

For each changed provider method, consider:

- success;
- provider-declared failure;
- transport/HTTP failure;
- empty response;
- malformed response;
- missing/invalid required runtime data.

Assert the outbound method/path/headers/body when those are part of the adapter
contract, as well as the mapped result.

Use the repository's established HTTP test mechanism. In Spring/WireMock projects,
prefer real serialization through the application client over mocking the client
itself when testing wire compatibility.

## Stateful behavior

For polling or callbacks, consider:

- pending → success;
- pending → final provider failure;
- timeout/deadline;
- callback replay;
- old serialized state produced by the previous deployed version;
- restart/retry behavior if continuation state is persistent.

The test name and fixture should describe the business scenario rather than reproduce
transport boilerplate.
