# Origin and licensing

Extracted from [Alicorn](https://github.com/samanshaiza004/alicorn) commit
`01d9253` on 2026-10-30. The initial extraction preserves the binding API and
behavior, including C ABI round-trip tests and ownership-transfer helpers.
Only test-library names, paths and project-specific comments changed.
Alicorn's retained semantics and SDL host adapter are not part of this repository.

The Odin wrapper, examples and tools retain their original zlib license in
[LICENSE](LICENSE). The original copyright notice is preserved. Upstream
AccessKit C is a separate dependency under its own Apache-2.0/MIT notices;
its release also includes AUTHORS and LICENSE.chromium for derived code. Bootstrap retrieves
these notices alongside the library; distributors must preserve applicable
upstream notices. No third-party binary is committed here.
