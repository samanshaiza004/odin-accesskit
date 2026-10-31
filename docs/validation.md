# Validation — v0.1.0, 2026-10-30

Validated release revision: [`9077671`](https://github.com/samanshaiza004/odin-accesskit/commit/907767158628a8f1959835152699a0cf6aad3566).
The [release-tag GitHub Actions run](https://github.com/samanshaiza004/odin-accesskit/actions/runs/41091327316)
completed successfully on all four targets.

| Target | Automated coverage | Result |
| --- | --- | --- |
| Windows x64 | C/Odin ABI checks, binding tests, external consumer, native Win32 smoke, and UI Automation patterns | Pass |
| macOS arm64 | C/Odin ABI checks, binding tests, external consumer, AppKit host build and contract smoke | Pass |
| macOS x64 | C/Odin ABI checks, binding tests, external consumer, AppKit host build and contract smoke | Pass |
| Linux x64 | C/Odin ABI checks, binding tests, and external consumer; no native AT-SPI adapter | Pass |

The macOS smoke is contract-level: it exercises the C-callable factories,
action queue, text editing and shutdown without creating an `NSApplication` or
window. It does **not** validate native adapter activation or VoiceOver speech.
Linux checks the core binding only; the Unix/AT-SPI adapter is not wrapped.

Local machine: Windows 10 x64, AMD Ryzen 5 7600X; Odin
`dev-2026-09-nightly:a2fb372`, MSVC x64 toolchain, AccessKit C 0.23.1.

`tools/check.ps1` passed:

- C-header ABI contract and generated assertions for 262 byte-enum values.
- Eight Odin tests, including real C Rect/TextSelection argument/return
  round trips, all eight C-created tagged payloads, metadata/string ownership,
  and numeric-payload bit reinterpretation.
- The complete Windows gate also passed with a native cache path containing spaces.
- A minimal consumer built and ran from an external temporary directory.
- Native Win32 example smoke: activation, worker queue, five actions,
  incremental updates, Unicode editing, focus and shutdown.
- Real Windows UIA Button/Value/Text patterns: Invoke, SetValue, selection,
  updated text, empty/limit checks and shutdown with retained provider references.

The native example's automated action checks are not a fresh Narrator/NVDA
speech validation. No independent manual screen-reader session was performed
for this binding. Previous Alicorn validation applies to Alicorn's integration,
not to every external consumer. Do not claim independent VoiceOver or Linux
screen-reader acceptance from adapter compilation or contract smoke tests.
