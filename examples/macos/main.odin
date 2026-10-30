package main

import "core:os"
import "core:fmt"

main :: proc() {
	if ODIN_OS != .Darwin {
		fmt.eprintln("The native window example requires macOS. The model tests can run on other platforms.")
		os.exit(2)
	}
	when ODIN_OS == .Darwin { os.exit(int(macos_main())) }
}
