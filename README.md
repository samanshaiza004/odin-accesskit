# odin-accesskit

Odin bindings for [AccessKit C](https://github.com/AccessKit/accesskit-c), for
custom-rendered UI toolkits and native applications. The package exposes nodes,
properties, tree updates, action requests and native Windows/macOS adapters.
It owns no application model, semantic diff engine, event loop or window.

The Odin API uses typed IDs, strings and slices with explicit ownership.
Public `accesskit_*` declarations expose the bound C ABI directly. Named
constants cover every role, action and byte-sized schema enum in the pinned
header. The raw C declarations are intentionally partial: 57 of 497 functions
in the pinned header are declared. That count is not a weighted feature-coverage
measure; see [api-coverage.json](api-coverage.json) for the exact list.

The `accesskit_c` collection identifies the exact native-library directory;
this avoids ambient linker searches and supports paths containing spaces.

Binding v0.1.0 targets **AccessKit C 0.23.1**. The upstream library and header
are downloaded together and verified with SHA-256. Rust is not required to
consume the prebuilt static libraries. Odin's API remains experimental.

## Build and check

Use an Odin installation on PATH. Windows additionally needs MSVC C++ build
tools and a Windows SDK; scripts initialize its x64 environment. macOS needs
Xcode command line tools, curl and unzip. Linux core checks need a C compiler,
ar, curl and unzip. The check scripts also require Python 3 to verify generated enum coverage.

```powershell
# Windows x64: bootstrap, C/Odin ABI round trips, ownership tests,
# external consumer, then native-window smoke.
.\tools\check.ps1
.\tools\run_example.ps1
```

```sh
# macOS arm64/x64 or Linux x64: core ABI tests and external consumer.
sh tools/check.sh
# Native macOS example:
sh tools/run_macos.sh
```

A minimal independent consumer imports one package:

```odin
package main

import ak "accesskit:accesskit"

main :: proc() {
    root, ok := ak.node_create(ak.ROLE_WINDOW)
    if !ok { return }
    defer ak.node_destroy(&root)
    ak.node_set_label(&root, "My application")
}
```

Build a project outside this repository with the same collection and native
link recipe (paths may be absolute):

```powershell
$binding = (Resolve-Path .).Path
$native = & "$binding\tools\bootstrap.ps1"
odin build C:\path\to\app "-collection:accesskit=$binding" @($native.CompilerArguments)
```

```sh
binding=/path/to/odin-accesskit
flags=$(sh "$binding/tools/bootstrap.sh")
libdir=$(sh "$binding/tools/bootstrap.sh" --library-directory)
odin build /path/to/app "-collection:accesskit=$binding" "-collection:accesskit_c=$libdir" "-extra-linker-flags:$flags"
```

`tools/check` builds the [minimal tree](examples/minimal_tree/main.odin) from
a temporary directory outside the repository. Native examples demonstrate
activation, update submission, action callbacks, focus and destruction without
Alicorn or SDL. Automated smoke is not a screen-reader compatibility claim.
See the [extraction validation record](docs/validation.md) for completed and
pending checks.

## Contracts

Read [ownership](docs/ownership.md), [C callbacks](docs/callbacks.md),
[text indices](docs/text.md), and [platform support](docs/platforms.md) before
integrating the adapters. [Origin and licensing](ORIGIN.md) records the
extraction from Alicorn; upstream AccessKit is a separate dependency.

## Development

After bootstrap, `python tools/generate_constants.py --check` verifies the
checked-in constants, C enum assertions and API coverage manifest against the
pinned header. Run without `--check` to regenerate after an intentional
upstream update. C tests verify layouts, enum values and aggregate calling
conventions; Odin tests verify string copying, tagged actions and consuming
handle operations. Changing upstream versions requires these gates on every
supported target.

The wrapper uses the [zlib license](LICENSE). Keep upstream AccessKit's
LICENSE-APACHE, LICENSE-MIT, LICENSE.chromium and AUTHORS with redistributed
upstream binaries. This is an independent community binding.
