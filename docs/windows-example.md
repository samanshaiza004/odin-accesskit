# Native Windows example

`examples/windows` is a standalone Win32/GDI consumer of
`accesskit:accesskit`, pinned to AccessKit C **0.23.1**. It imports
`core:sys/windows` directly and has no Alicorn or SDL dependency. All controls
are drawn in one native top-level window; there are no native child controls.
This example requires no changes to the binding.

## Build and run

From the repository root, use the pinned bootstrap and native build helper:

```powershell
.\tools\run_example.ps1
.\tools\run_example.ps1 -Smoke
```

`tools/check.ps1` also builds and runs this example. Bootstrap verifies the
AccessKit C 0.23.1 static archive and header and needs no Rust installation.

## Interaction and accessible tree

- Tab or Shift+Tab moves between the two controls. With two stops, both
  directions toggle focus. The focus outline follows native window focus.
- Space or Enter activates the focused button. Clicking the button also
  activates it. A visible, polite live status reports the press count.
- Click the field to focus it and move the caret to the end. Type to edit;
  Left/Right, Home/End, Shift selection, Ctrl+A, Backspace, and Delete work.
  Supplementary Unicode characters arriving as `WM_CHAR` surrogate pairs
  are decoded before editing. Long text scrolls horizontally to the caret.
- Escape or the window's close button shuts down the example.

The tree has stable IDs throughout the window's lifetime:

| ID | Role in the pinned binding | Content/actions |
| --- | --- | --- |
| 1 | `ROLE_WINDOW` | Root, with children 2, 3, and 5 |
| 2 | `ROLE_BUTTON` | “Press me”; Focus and Click |
| 3 | `ROLE_TEXT_INPUT` | Editable TextField “Message”; Focus, SetValue, SetTextSelection, ReplaceSelectedText |
| 4 | `ROLE_TEXT_RUN` | Child of 3; UTF-8 value and character byte lengths |
| 5 | `ROLE_STATUS` | Button press count; polite, atomic live region |

TextInput is the pinned API's role name for the editable field. Its selection
uses positions in TextRun 4, with one Unicode scalar per example character.
For example, `Odin 🦄` has six characters and UTF-8 lengths `[1,1,1,1,1,4]`.
The field and run both carry the current value; an empty field retains run 4.
Node bounds use the same client coordinates as drawing and hit testing.

Activation returns the complete five-node tree plus tree info. Subsequent
updates always include focus and only replace the affected nodes:

- Focus movement: no replacement nodes.
- Selection movement: field 3 only.
- Editing/SetValue/ReplaceSelectedText: field 3 and run 4.
- Button activation: status 5 only.
- Resizing: root 1 only.

When inactive, the adapter skips the update factory. A later activation builds
the current complete state. Every returned non-nil event queue is raised once,
outside the mailbox lock. AccessKit's subclass handles `WM_GETOBJECT` and
native window focus transitions. The HWND is created without `WS_VISIBLE`,
and adapter creation happens on its owning thread before `ShowWindow`.

## Threading, ownership, and shutdown

The C action callback starts with `context = runtime.default_context()`, takes
the transferred request, snapshots its payload (including a separately
allocated string), and frees the C request with
`action_request_snapshot_and_destroy`. It only receives a mailbox pointer,
never the application's mutable state.

A process-lifetime mailbox uses a Windows SRW lock and a 64-slot FIFO of
`Owned_Action_Request` values. Ownership moves into the FIFO, clearing the
source handle. The callback posts a private `WM_APP` message while holding
the lock. The window procedure pops requests under the lock, releases it,
applies actions on the UI thread, and destroys each owned snapshot. A full or
closed mailbox, or a failed `PostMessage`, destroys the incoming snapshot
instead of leaking it. Work per wakeup is bounded to keep messages responsive.

Activation and update factories are `proc "c"`, establish Odin context, and
assert the window thread. The pinned adapter guarantees activation on that
thread; update factories run synchronously inside the UI thread's update call.
Tree nodes/info move into each update, and `tree_update_take` transfers the
finished update to AccessKit.

Shutdown first closes the mailbox under the lock and frees pending snapshots,
then destroys the adapter **before** the HWND. The message loop exits, the
optional smoke worker is joined, its handle is closed, and the window class is
unregistered. The mailbox and its zero-initialized SRW lock remain in static
storage until process exit: retained external UIA providers may keep the
callback alive beyond adapter destruction. A late action can therefore safely
copy/free its request and observe the closed mailbox, with no dangling App or
HWND access. The SRW lock needs no destruction.

## Automated checks

The executable's bounded check creates a real native window and UIA provider,
forces activation with `WM_GETOBJECT`, and starts a Win32 worker thread:

```powershell
& ./out/accesskit_windows.exe --smoke
if ($LASTEXITCODE -ne 0) { throw 'Smoke check failed' }
```

The worker copies Focus, SetValue, SetTextSelection, ReplaceSelectedText, and
Click payloads into the actual synchronized queue. The UI thread checks the
resulting text, status, focus, and incremental factories, then routes keyboard
navigation and UTF-16 surrogate input through the real window procedure.
Success prints `SMOKE PASS` and exits 0; failure exits nonzero. A 50 ms window
timer enforces a three-second deadline while the message loop is responsive;
worker joining adds at most one second. CI should also set a process timeout
to cover OS/driver/API hangs. A Windows session capable of creating HWNDs and
using UI Automation is required.

Smoke payloads use `action_request_copy` on borrowed synthetic views. They do
not fabricate Rust-owned C requests or claim to validate foreign request
allocation. The separate integration check calls through the real Windows UIA
provider and therefore exercises the actual C action callback:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File examples/windows/verify-uia.ps1 -Executable out/accesskit_windows.exe
```

This script uses Windows PowerShell 5.1/.NET Framework's UIAutomationClient,
launches its own example process hidden, and verifies Button/Value/Text
patterns, Invoke, SetValue, SetTextSelection, updated TextRun content, empty
text, the length limit, rejected multiline input, and shutdown while holding
provider references. Success prints `UIA PASS`; assertions exit nonzero. Use
an external process timeout for this check too, since UIA calls are synchronous.

Validated locally on Windows x64 with Odin
`dev-2026-09-nightly:a2fb372` and the existing AccessKit C 0.23.1 MSVC static
library: debug build, optimized builds with `-vet` (including
`-disable-assert`), `--smoke`, and the external UIA check.
No screen-reader session was performed for this example.

## Deliberate limits

This is a small single-line editor, not a full text widget. It supports at most
256 Unicode scalars and rejects invalid UTF-8, control characters, line breaks,
and edits exceeding that limit atomically. Character navigation uses scalars,
not grapheme clusters; it has no IME composition, clipboard, undo, word
navigation, mouse range selection, or text shaping/bidirectional layout.
The GDI font may show fallback glyphs for some characters. The caret does not
blink. Layout uses fixed client coordinates and minimum window dimensions.
TextRun bounds are approximate: per-character geometry and text direction are
not supplied, so precise UIA text-range rectangles/hit testing are outside this
example. Queue saturation drops incoming actions. Only Windows x64 has been
built and exercised here; Narrator/NVDA behavior and other architectures remain
to be checked manually.
