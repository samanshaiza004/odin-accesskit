# Platforms and validation

| Target | Contract |
| --- | --- |
| Windows x64 / MSVC | Core binding, native HWND subclassing adapter, C ABI and native example checks |
| macOS arm64 / x64 | Core binding, NSWindow subclassing adapter, C ABI and native example checks |
| Linux x64 | Core binding and C ABI; native AT-SPI adapter is not wrapped |
| Other targets | Untested; no support promise |

CI checks the actual C compiler/Odin aggregate argument and return ABI for
Rect and TextSelection, not just struct sizes. The native adapter examples
are small integration fixtures. Their smoke exits do not prove real
Narrator/NVDA/VoiceOver behavior. The binding was previously exercised through
Alicorn on Windows and macOS; that evidence applies to Alicorn's host, not
every external consumer. Test a new host with the relevant screen reader.

Create the Windows adapter on the HWND-owning thread before the window is
shown/focused. Update, focus-state notification and destruction belong on
that thread. On macOS, create a valid NSWindow and content view on the main
thread, then attach the adapter before showing the window. Keep the native
window alive until adapter destruction. AccessKit uses top-left/y-down
coordinates; the host must follow its adapter coordinate contract and keep
bounds consistent when display scale changes.

macOS `macos_add_focus_forwarder_to_window_class` installs permanent methods
on an NSWindow subclass. AccessKit must remain loaded for the process lifetime;
the bootstrap's static linkage provides that lifetime. Native adapters own
neither your windows nor application state. Inactive adapters can return nil
event queues; non-nil queues must be raised exactly once.

The bootstrap retrieves matching libraries and headers from AccessKit C
0.23.1, verifies SHA-256, and needs no Rust installation. Source builds are
possible using [upstream's instructions](https://github.com/AccessKit/accesskit-c/tree/0.23.1);
keep the same version, target architecture and linkage contract.
