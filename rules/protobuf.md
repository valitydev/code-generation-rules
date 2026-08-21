# Protobuf

- Use versioned packages and directories.
- Keep field types wire-compatible.
- Field numbers are immutable after publication.
- Removed fields and names are reserved.
- Add compatibility tests when a consumer may receive a newly added `oneof` variant
  or enum value.
