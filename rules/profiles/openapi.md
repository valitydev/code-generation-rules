# OpenAPI contract conventions

These rules extend the common rules for repositories that own an OpenAPI contract and
publish generated server or client artifacts.

## Contract structure

- One root OpenAPI document is the source entry point. Paths and reusable components
  are split into focused files and connected through local `$ref` references.
- Every operation has a stable, unique `operationId`, an appropriate tag, and explicit
  request parameters, request body, responses, and security requirements.
- Common parameters, error responses, schemas, and security schemes are defined once
  under `components` and reused instead of being copied between operations.
- Public operations require and document a request or correlation identifier and use a
  shared typed error schema.
- Schema fields declare `required`, `nullable`, formats, enums, bounds, and collection
  constraints explicitly whenever they are part of the contract.
