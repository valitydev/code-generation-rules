# OpenAPI contract reference

Read this only when the task changes an OpenAPI document, generated API artifact, or
contract compatibility.

- Treat the repository's root OpenAPI document as the contract source, not generated
  server/client code.
- Preserve stable `operationId` values unless the change intentionally coordinates a
  breaking API migration.
- Reuse shared parameters, error schemas, security schemes, and components rather than
  copying equivalent definitions.
- Make request/response constraints explicit when they are part of the public
  contract: required/nullable state, formats, enums, bounds, and collection limits.
- Keep the project's existing request/correlation-id and typed-error conventions.
- Run the repository's OpenAPI validation and regenerate affected artifacts in the
  same change.
- Review the generated diff for accidental contract churn.
