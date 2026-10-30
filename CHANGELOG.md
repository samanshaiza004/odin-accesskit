# Changelog

## 0.1.0 (unreleased)

- Extract the independent Odin binding and C ABI contracts from Alicorn.
- Preserve AccessKit C 0.23.1; verify binary/header downloads with SHA-256.
- Keep typed owning handles, safe action snapshots and native Windows/macOS adapters.
- Provide independent core consumer and native examples, external-import checks,
  aggregate ABI round trips and Windows/macOS/Linux core CI.
- Add every named role/action/byte enum from the pinned C header, generated
  coverage assertions, and an explicit manifest of remaining raw C functions.
- Fix NumericValue union decoding to reinterpret the f64 bits. A C-created
  regression covers every supported tagged action payload.
- Confirm tree-info ownership against upstream and test metadata after transfer.
- Document ownership, callbacks, Unicode indices, platform lifetimes and limits.
