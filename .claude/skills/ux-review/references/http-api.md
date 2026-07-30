# HTTP and RPC API Checklist

Read after Step 2 of the core workflow, when the medium is api.

## Naming and shape

- Paths name resources as plural nouns; the HTTP method carries the verb. A path segment that is a verb usually means the resource is missing.
- One concept, one name, across path, query, request body, and response body. A field called merchantId in one place and merchant_code in another is two concepts as far as the caller knows.
- Casing is consistent across the whole surface. Pick one and never mix.
- Required and optional fields are distinguishable without trying the call.
- A field whose meaning depends on the value of another field needs either splitting into two endpoints or a discriminator the caller sets explicitly.
- Enumerated values are closed, documented strings, not free text and not opaque integers.

## Status codes and errors

- Status codes carry their standard meaning. 200 with an error body inside is the single most expensive API mistake, because every caller must then parse success twice.
- Distinguish 400 caller error, 401 unauthenticated, 403 unauthorized, 404 absent, 409 conflict, 422 semantically invalid, 429 throttled, 5xx our fault. Callers retry on some of these and must not retry on others.
- Error bodies have one shape across the entire surface, with a stable machine-readable code, a human message, and the offending field where applicable.
- The error code is stable and greppable. The human message may change; the code may not.
- Errors carry the identifiers a caller needs to act: which request, which field, which resource.
- Say whether the failure is retryable. Callers will guess otherwise, and guess wrong.

## Contract and evolution

- Adding a field is safe; removing or repurposing one is not. Repurposing an existing field is the worst option available.
- Version the surface before the first external caller, not after.
- Deprecation is announced in the response, not only in a document nobody fetches.
- Defaults never change silently. A changed default is a behavior change for every existing caller.

## Reliability affordances

- Any endpoint that creates or moves money accepts an idempotency key, and repeating the same key returns the original result rather than a conflict.
- Collection endpoints paginate from day one, with a documented ordering. Unordered pagination is broken pagination.
- State the timeout the caller should use, and behave predictably when the caller gives up: either the operation completed or it did not, and there is a way to find out which.
- Partial failure in a batch endpoint reports per-item outcomes. A batch that returns one overall status forces callers to retry the whole thing.
- Long operations return a handle the caller can poll, rather than holding a connection open.

## Common findings to look for

| Symptom | Usual fix |
|---|---|
| Callers check the body to know if the call succeeded | Use status codes correctly |
| Every caller has its own retry rules | Mark retryability in the error body |
| Duplicate charges under network retry | Add idempotency keys |
| Support cannot trace a failure from the caller's report | Put a request identifier in every response |
| Callers hardcode a substring of the error message | Add a stable error code |
| A new field broke existing clients | Fields must be additive; version instead |
