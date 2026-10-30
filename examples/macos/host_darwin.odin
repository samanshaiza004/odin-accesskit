package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import ak "accesskit:accesskit"

foreign import host_shim "accesskit_example_host:libodin_accesskit_example_host.a"

Host_Event :: proc "c" (userdata: rawptr, event: i32, text: rawptr, length: uint, argument: i32, shift: bool)
Host_Worker :: proc "c" (userdata: rawptr)
foreign host_shim {
	example_host_create :: proc "c" (callback: Host_Event, userdata: rawptr) -> rawptr ---
	example_host_window :: proc "c" (host: rawptr) -> rawptr ---
	example_host_present :: proc "c" (host: rawptr, button: rawptr, button_length: uint, text: rawptr, text_length: uint, focus: u64, anchor, caret: uint) ---
	example_host_run :: proc "c" (host: rawptr) ---
	example_host_focus :: proc "c" (host: rawptr) ---
	example_host_stop :: proc "c" (host: rawptr) ---
	example_host_destroy :: proc "c" (host: rawptr) ---
	example_host_is_main_thread :: proc "c" () -> bool ---
	example_host_run_worker :: proc "c" (callback: Host_Worker, userdata: rawptr) -> bool ---
}

App :: struct {
	host: rawptr,
	adapter: ak.MacOS_Subclassing_Adapter,
	snapshot: Snapshot,
	updates: u64,
}

// Callbacks only retain this process-lifetime bridge, never App or NSWindow.
bridge: Bridge

present :: proc(app: ^App) {
	assert(example_host_is_main_thread())
	publish(&bridge, app.snapshot)
	encoded := encode_text(&app.snapshot)
	buffer: [96]u8
	label := button_label(&app.snapshot, buffer[:])
	example_host_present(app.host, rawptr(raw_data(label)), uint(len(label)),
		rawptr(&encoded.bytes[0]), uint(encoded.length), u64(app.snapshot.focus),
		uint(app.snapshot.anchor), uint(app.snapshot.caret))
	events := ak.macos_subclassing_adapter_update_if_active(&app.adapter, update_factory, &bridge)
	ak.macos_queued_events_raise(&events)
	app.updates += 1
}

host_event :: proc "c" (userdata: rawptr, event: i32, text: rawptr, length: uint, argument: i32, shift: bool) {
	context = runtime.default_context()
	assert(example_host_is_main_thread())
	app := cast(^App)userdata
	changed := false
	switch event {
	case 0: // timer drains bounded work on the UI thread (including menu tracking)
		for i := 0; i < QUEUE_CAPACITY; i += 1 {
			command, ok := dequeue(&bridge)
			if !ok { break }
			changed = apply_command(&app.snapshot, command) || changed
		}
	case 1:
		changed = handle_key(&app.snapshot, int(argument), shift)
	case 2:
		if app.snapshot.focus == FIELD && text != nil {
			inserted: [MAX_TEXT]rune
			count, ok := decode_text(string((cast([^]u8)text)[:int(length)]), &inserted)
			if ok { changed = replace_selection(&app.snapshot, inserted[:count]) }
		}
	case 3:
		events := ak.macos_subclassing_adapter_update_focus_state(&app.adapter, argument != 0)
		ak.macos_queued_events_raise(&events)
	case 4:
		if argument == i32(BUTTON) {
			changed = apply_command(&app.snapshot, {action = ak.ACTION_CLICK, target = BUTTON})
		} else if argument == i32(FIELD) {
			app.snapshot.focus = FIELD
			app.snapshot.anchor, app.snapshot.caret = app.snapshot.length, app.snapshot.length
			changed = true
		}
	}
	if changed {
		present(app)
		// Accessibility actions also restore native keyboard focus to the view.
		if event == 0 { example_host_focus(app.host) }
	}
}

macos_main :: proc() -> c.int {
	assert(example_host_is_main_thread())
	for argument in os.args[1:] {
		if argument == "--smoke" { return run_smoke() }
		fmt.eprintln("Usage: macos-example [--smoke]")
		return 2
	}
	app := App{snapshot = initial_snapshot()}
	bridge.accepting = true
	publish(&bridge, app.snapshot)
	app.host = example_host_create(host_event, &app)
	if app.host == nil { fmt.eprintln("Could not create NSWindow"); return 1 }
	// Defers execute in reverse order: gate callbacks, free adapter, release host.
	defer example_host_destroy(app.host)
	adapter, ok := ak.macos_subclassing_adapter_create_for_window(
		example_host_window(app.host), activation_callback, &bridge, action_callback, &bridge)
	if !ok { stop_accepting(&bridge); fmt.eprintln("Could not create AccessKit adapter"); return 1 }
	app.adapter = adapter
	defer ak.macos_subclassing_adapter_destroy(&app.adapter)
	defer stop_accepting(&bridge)
	// The content view itself becomes first responder. No permanent NSWindow
	// focus-forwarding patch is needed for this host.
	present(&app)
	example_host_run(app.host)
	return 0
}
