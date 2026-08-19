# Generated contracts and Protobuf reference

Read this only for generated sources, Protobuf, OpenAPI generation, or another
published generated contract.

## Generated code

- Never edit generated output as the source of a fix.
- Change the source schema/specification/generator and regenerate.
- Generation should be reproducible in CI from repository state.
- Review generated diffs for unrelated churn.

## Protobuf

- Published field numbers are immutable.
- Reserve removed field numbers and names.
- Preserve wire-compatible field types.
- Use the repository's established package/versioning strategy.
- When consumers may receive new enum values, oneof variants, or messages, add or
  update compatibility tests and tolerant handling as appropriate.

If a change is intentionally breaking, make the break explicit and coordinate the
producer/consumer migration rather than silently weakening these rules.
