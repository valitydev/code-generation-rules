# Template adaptation and drift control

Use when implementing a new provider from an existing adapter/template or substantially
remapping an existing adapter to a new provider contract.

Before editing, separate generic local infrastructure from assumptions belonging to
the previous provider. A copied field, status mapping, callback format, fixture,
polling rule, or request option needs evidence in the new provider contract or the
actual local flow; similarity to the template is not enough.

Prefer the closest working local template for mechanics, but minimize copied
provider-specific behavior. Do not carry optional request fields forward unless the
new flow needs them.

After implementation:

- search for stale provider names, old endpoints/statuses, unused constants,
  unreachable branches, obsolete fixtures, and response fields no longer consumed;
- review every removed callback, polling, correlation, error, and continuation-state
  branch and confirm the removal is intentional;
- confirm every new fixture is referenced by a test and every material error fixture
  has an assertion capable of observing the mapped failure;
- review the final diff for unrelated template cleanup that should not be part of the
  provider change.

The goal is not to make the new adapter resemble the template. The goal is to reuse
proven local mechanics while making every provider-specific element traceable to the
current provider contract or the concrete adapter flow.
