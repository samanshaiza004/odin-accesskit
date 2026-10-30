package main

import "base:runtime"
import "core:c"
import "core:fmt"
import ak "accesskit:accesskit"

Smoke_Work :: struct {
	bridge: ^Bridge,
	ok: bool,
}

// This runs on a pthread created by the C shim, so it also checks that a real
// foreign-thread callback can establish context and copy text into the mailbox.
smoke_worker :: proc "c" (userdata: rawptr) {
	context = runtime.default_context()
	work := cast(^Smoke_Work)userdata
	work.ok = !example_host_is_main_thread()
	views := [5]ak.Borrowed_Action_Request{
		{action = ak.ACTION_FOCUS, target_node = FIELD},
		{action = ak.ACTION_SET_VALUE, target_node = FIELD, has_data = true, data_tag = ak.ACTION_DATA_VALUE, text_value = "Odin 🦄"},
		{action = ak.ACTION_SET_TEXT_SELECTION, target_node = FIELD, has_data = true, data_tag = ak.ACTION_DATA_SET_TEXT_SELECTION},
		{action = ak.ACTION_REPLACE_SELECTED_TEXT, target_node = FIELD, has_data = true, data_tag = ak.ACTION_DATA_VALUE, text_value = "Native"},
		{action = ak.ACTION_CLICK, target_node = BUTTON},
	}
	views[2].payload.value = transmute([4]u64)ak.Text_Selection{{u64(RUN), 0}, {u64(RUN), 4}}
	for view in views { work.ok = enqueue_view(work.bridge, view) && work.ok }
}

run_smoke :: proc() -> c.int {
	s := initial_snapshot()
	mailbox := Bridge{accepting = true, published = s}
	// Invoke the actual C-callable factories and release their real AccessKit
	// allocations. This deliberately does not activate an NSAccessibility adapter.
	initial := ak.Tree_Update{raw = activation_callback(&mailbox)}
	if initial.raw == nil { return 1 }
	ak.tree_update_destroy(&initial)
	work := Smoke_Work{bridge = &mailbox}
	if !example_host_run_worker(smoke_worker, &work) || !work.ok {
		fmt.eprintln("SMOKE FAIL: worker/mailbox")
		return 1
	}
	// The producer has not applied its actions to the application snapshot.
	ok := s.focus == BUTTON && s.presses == 0 && mailbox.count == 5
	for {
		command, available := dequeue(&mailbox)
		if !available { break }
		ok = apply_command(&s, command) && ok
	}
	encoded := encode_text(&s)
	ok = ok && string(encoded.bytes[:encoded.length]) == "Native 🦄" && s.focus == BUTTON && s.presses == 1
	ok = handle_key(&s, KEY_TAB, false) && ok
	ok = handle_key(&s, KEY_END, false) && ok
	unicorn := [1]rune{'🦄'}
	ok = replace_selection(&s, unicorn[:]) && ok
	ok = handle_key(&s, KEY_BACKSPACE, false) && ok
	encoded = encode_text(&s)
	ok = ok && string(encoded.bytes[:encoded.length]) == "Native 🦄"
	publish(&mailbox, s)
	update := ak.Tree_Update{raw = update_factory(&mailbox)}
	ok = ok && update.raw != nil
	ak.tree_update_destroy(&update)
	// An empty TextRun must also cross the C FFI with a non-null slice pointer.
	s.anchor, s.caret = 0, s.length
	ok = replace_selection(&s, nil) && ok
	publish(&mailbox, s)
	update = ak.Tree_Update{raw = update_factory(&mailbox)}
	ok = ok && update.raw != nil
	ak.tree_update_destroy(&update)
	stop_accepting(&mailbox)
	ok = !enqueue(&mailbox, {action = ak.ACTION_CLICK, target = BUTTON}) && ok
	late := ak.Tree_Update{raw = activation_callback(&mailbox)}
	ok = ok && late.raw != nil && mailbox.count == 0 && mailbox.rejected == 1
	ak.tree_update_destroy(&late)
	if !ok { fmt.eprintln("SMOKE FAIL: activation/action/update/shutdown contract"); return 1 }
	fmt.println("SMOKE PASS: core activation/action/update/shutdown contract; foreign-thread queue, Unicode editing. No VoiceOver validation.")
	return 0
}
