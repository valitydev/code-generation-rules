# Code generation

- Generated sources are never edited manually.
- Protobuf field numbers are immutable after publication.
- Removed protobuf fields and names are reserved.
- OpenAPI changes are validated and generated clients are rebuilt in the same pull request.
- Generation must be deterministic and runnable in CI without repository-local state.
