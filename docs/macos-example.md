# Native macOS example

`examples/macos` is an independent consumer of `accesskit:accesskit` and the
pinned AccessKit C **0.23.1** static library. It imports no Alicorn or SDL code
and does not change the binding. A small Objective-C host owns an `NSWindow`
and one custom-drawn `NSView`; Odin owns the application model and semantic tree.

On macOS 11 or later, install Odin and the Xcode command line tools, then run
from the repository root:

```sh
sh tools/run_macos.sh
```

The runner uses the exact `uname -s = Darwin` gate, gets verified static linker
flags from `tools/bootstrap.sh`, compiles `host.m` with ARC and warnings as
errors, archives it with `xcrun libtool`, builds the Odin executable, and runs it.
Both arm64 and x86_64 are selected from `uname -m`; the host shim and Odin target
use the same architecture. Use a matching Odin toolchain. Optional configuration:

```sh
ODIN=/absolute/path/to/odin \
ACCESSKIT_CACHE_ROOT=/absolute/path/to/accesskit-cache \
sh tools/run_macos.sh --smoke
```

`ODIN` is an executable path. `ACCESSKIT_CACHE_ROOT` is passed through the
environment to bootstrap and can reuse the parent's dependency cache. Artifacts
go to `examples/macos/build/`, ignored in its entirety by the example's own
`.gitignore`. The built executable can subsequently be run directly:

```sh
examples/macos/build/macos-example
examples/macos/build/macos-example --smoke
```

The window displays a Button and a Message text field. Tab or Shift-Tab switches
focus; Space or Return presses the focused button. Clicking the field focuses
it with the caret at the end. Type to edit; Left/Right, Home/End, Shift with those
keys, Cmd-A, Backspace, and forward Delete operate on the selection. Closing the
window or Cmd-Q stops the event loop and performs ordered teardown.

The stable semantic IDs are Window (1), Button (2), TextInput (3, exposed as the
native TextField role), and its TextRun (4). Button advertises Click and Focus;
the field advertises Focus, SetValue, ReplaceSelectedText, and SetTextSelection.
The run provides UTF-8 byte lengths for each Unicode scalar, and the field's
selection refers to run 4. Semantic bounds use view-local points with a
top-left origin, matching the flipped custom view. Every change publishes a
complete four-node update through `update_if_active`, then raises its returned
queued events exactly once. Native window/view focus changes use the adapter's
focus-state update and follow the same event ownership rule.

All C callbacks use `proc "c"` and establish `runtime.default_context()`.
Activation and update factories copy a synchronized, published snapshot and
return a newly owned C tree update. The action callback borrows the transferred
C request only long enough to copy its text/selection into a fixed-capacity,
mutex-protected queue, then frees the request exactly once. No application or
AppKit state is changed in that callback. A 10 ms main-run-loop timer drains at
most 32 commands per tick; only the UI thread edits the model, redraws, restores
native keyboard focus, or calls the adapter lifecycle API. The queue rejects
overflow, shutdown submissions, and invalid/oversized text without retaining
borrowed pointers. Text storage is limited to 64 Unicode scalars.

The host supplies a borrowed window handle after creating its content view and
before showing the window. Its content view becomes first responder, so no
permanent NSWindow focus-forwarding patch is installed. On exit, Odin closes the
queue, destroys the adapter, then tells the host to close/release the window.
The callback bridge has process lifetime and contains no App or native handle
pointers. Pending inline commands are discarded on shutdown; late action
callbacks can still safely reject and free their C request. Each tree's node
and tree-info ownership is transferred through the binding's owning wrappers.

`--smoke` creates no NSApplication or window and runs no UI event loop. It checks
the actual C-callable activation/update factories with real AccessKit tree
allocations, sends copied action views from a foreign pthread, verifies that
only the consumer applies them, exercises Unicode replacement/selection and
keyboard deletion, builds an empty TextRun, and checks shutdown rejection and
late activation. It normally exits immediately with `SMOKE PASS` and status 0;
failure returns nonzero. Action views use the same copy/queue path as the real
callback; smoke does not fabricate Rust-owned action requests. This is a core
contract smoke, **not native adapter activation or VoiceOver validation**.

Local verification available on the Windows development host:

```sh
odin check examples/macos -collection:accesskit=. -target:darwin_arm64 -vet -warnings-as-errors
odin check examples/macos -collection:accesskit=. -target:darwin_amd64 -vet -warnings-as-errors
```

Both targets also successfully generated macOS object files using
`-build-mode:obj`. Three platform-independent Odin tests passed against the
Windows AccessKit 0.23.1 static library: Unicode/selection and tree allocation,
mailbox overflow/shutdown, and worker-thread copying without application
mutation. The runner passed shell syntax checking and rejected the Windows
host with status 1 before attempting AppKit compilation.

The Objective-C host has **not** been compiled or run against a macOS SDK here.
macOS linking, the foreign-pthread smoke, window interaction, native accessibility
activation, and VoiceOver remain pending a macOS machine or approved CI run.
For a manual check, run the window with VoiceOver enabled (Cmd-F5), inspect the
Button and Message field with Accessibility Inspector, press the button, edit
the text, move the selection, switch windows to test focus loss/recovery, and
close the window. Record OS, architecture, Odin version, and reader version
alongside results before claiming native accessibility validation.

This is a minimal editor: no IME/marked text, clipboard, undo, grapheme-cluster
navigation, horizontal scrolling, or per-character accessibility geometry.
Its TextRun bounds cover the text area; fine-grained text hit testing and
character-range geometry need a fuller layout implementation.
