package main

import "base:runtime"
import "core:fmt"
import win "core:sys/windows"
import ak "accesskit:accesskit"

Changed :: enum { Root, Button, Field, Run, Status }
Changes :: bit_set[Changed]
ALL_NODES :: Changes{.Root, .Button, .Field, .Run, .Status}
Update_Args :: struct { app: ^App, changed: Changes, initial: bool }

require_accesskit :: proc(ok: bool) {
	// Ownership transfers must execute even in builds using -disable-assert.
	if !ok { panic("AccessKit allocation or ownership transfer failed") }
}

bounds :: proc(rect: win.RECT) -> ak.Rect {
	return {f64(rect.left), f64(rect.top), f64(rect.right), f64(rect.bottom)}
}

build_update :: proc(args: Update_Args) -> rawptr {
	app := args.app
	on_ui_thread(app)
	update, ok := ak.tree_update_create(5, app.focus)
	require_accesskit(ok)
	defer ak.tree_update_destroy(&update)
	if args.initial {
		tree, tree_ok := ak.tree_info_create(ROOT)
		require_accesskit(tree_ok)
		ak.tree_info_set_toolkit_name(&tree, "Standalone Odin Win32 example")
		ak.tree_info_set_toolkit_version(&tree, "AccessKit C 0.23.1")
		require_accesskit(ak.tree_update_set_tree_info(&update, &tree))
	}
	if .Root in args.changed {
		root, node_ok := ak.node_create(ak.ROLE_WINDOW)
		require_accesskit(node_ok)
		ak.node_set_label(&root, "AccessKit Odin native example")
		ak.node_push_child(&root, BUTTON)
		ak.node_push_child(&root, FIELD)
		ak.node_push_child(&root, STATUS)
		rect: win.RECT
		win.GetClientRect(app.hwnd, &rect)
		ak.node_set_bounds(&root, bounds(rect))
		require_accesskit(ak.tree_update_push_node(&update, ROOT, &root))
	}
	if .Button in args.changed {
		button, node_ok := ak.node_create(ak.ROLE_BUTTON)
		require_accesskit(node_ok)
		ak.node_set_label(&button, "Press me")
		ak.node_set_bounds(&button, bounds(BUTTON_RECT))
		ak.node_add_action(&button, ak.ACTION_FOCUS)
		ak.node_add_action(&button, ak.ACTION_CLICK)
		require_accesskit(ak.tree_update_push_node(&update, BUTTON, &button))
	}
	text := encode_text(app)
	if .Field in args.changed {
		// TextInput is the pinned 0.23.1 name for the editable TextField role.
		field, node_ok := ak.node_create(ak.ROLE_TEXT_INPUT)
		require_accesskit(node_ok)
		ak.node_set_label(&field, "Message")
		ak.node_set_description(&field, "Single line; at most 256 Unicode scalar values")
		ak.node_set_bounds(&field, bounds(FIELD_RECT))
		ak.node_set_value(&field, string(text.bytes[:text.length]))
		ak.node_push_child(&field, RUN)
		ak.node_set_text_selection(&field, {
			anchor = {u64(RUN), uint(app.anchor)}, focus = {u64(RUN), uint(app.caret)},
		})
		for action in ([4]ak.Action{ak.ACTION_FOCUS, ak.ACTION_SET_VALUE, ak.ACTION_SET_TEXT_SELECTION, ak.ACTION_REPLACE_SELECTED_TEXT}) {
			ak.node_add_action(&field, action)
		}
		require_accesskit(ak.tree_update_push_node(&update, FIELD, &field))
	}
	if .Run in args.changed {
		run, node_ok := ak.node_create(ak.ROLE_TEXT_RUN)
		require_accesskit(node_ok)
		ak.node_set_value(&run, string(text.bytes[:text.length]))
		ak.node_set_bounds(&run, bounds({32, 146, 528, 172}))
		// Each example character is one Unicode scalar, measured in UTF-8 bytes.
		// Empty text retains this TextRun with an empty lengths array.
		ak.node_set_character_lengths(&run, text.lengths[:app.length])
		require_accesskit(ak.tree_update_push_node(&update, RUN, &run))
	}
	if .Status in args.changed {
		status, node_ok := ak.node_create(ak.ROLE_STATUS)
		require_accesskit(node_ok)
		buffer: [80]u8
		ak.node_set_label(&status, fmt.bprintf(buffer[:], "Button pressed %d time(s)", app.presses))
		ak.node_set_bounds(&status, bounds({24, 190, 536, 218}))
		ak.node_set_live(&status, ak.LIVE_POLITE)
		ak.node_set_live_atomic(&status)
		require_accesskit(ak.tree_update_push_node(&update, STATUS, &status))
	}
	return ak.tree_update_take(&update)
}

activate :: proc "c" (userdata: rawptr) -> rawptr {
	context = runtime.default_context()
	app := cast(^App)userdata
	on_ui_thread(app)
	app.activations += 1
	app.full_updates += 1
	return build_update({app, ALL_NODES, true})
}

update_factory :: proc "c" (userdata: rawptr) -> rawptr {
	context = runtime.default_context()
	args := cast(^Update_Args)userdata
	on_ui_thread(args.app)
	args.app.updates += 1
	if args.changed == {} { args.app.focus_updates += 1 }
	if args.changed == {.Field} { args.app.selection_updates += 1 }
	if args.changed == {.Field, .Run} { args.app.text_updates += 1 }
	if args.changed == {.Status} { args.app.status_updates += 1 }
	return build_update(args^)
}

publish :: proc(app: ^App, changed: Changes) {
	on_ui_thread(app)
	if app.closing { return }
	args := Update_Args{app, changed, false}
	// The factory is synchronous, so stack userdata remains valid for the call.
	events := ak.windows_subclassing_adapter_update_if_active(&app.adapter, update_factory, &args)
	ak.windows_queued_events_raise(&events)
	win.InvalidateRect(app.hwnd, nil, false)
}

// Only mailbox fields are shared. No callback receives an App pointer.
Mailbox :: struct {
	lock: win.SRWLOCK,
	hwnd: win.HWND,
	closed: bool,
	requests: [64]ak.Owned_Action_Request,
	head, count: int,
	rejected: int,
}
mailbox: Mailbox

// Consumes owned, on both success and failure. Post while holding the lock so
// close_mailbox cannot destroy the HWND between the check and the wakeup.
enqueue :: proc(queue: ^Mailbox, owned: ^ak.Owned_Action_Request) {
	win.AcquireSRWLockExclusive(&queue.lock)
	defer win.ReleaseSRWLockExclusive(&queue.lock)
	if queue.closed || queue.count == len(queue.requests) || !win.PostMessageW(queue.hwnd, ACTION_MESSAGE, 0, 0) {
		queue.rejected += 1
		ak.owned_action_request_destroy(owned)
		return
	}
	index := (queue.head + queue.count) % len(queue.requests)
	queue.requests[index] = owned^
	owned^ = {} // Move ownership, never keep a second live owning copy.
	queue.count += 1
}

action_callback :: proc "c" (raw_request: rawptr, userdata: rawptr) {
	// Foreign/COM threads do not carry Odin's implicit context.
	context = runtime.default_context()
	request := ak.action_request_take(raw_request)
	owned, ok := ak.action_request_snapshot_and_destroy(&request, context.allocator)
	if !ok { ak.owned_action_request_destroy(&owned); return }
	enqueue(cast(^Mailbox)userdata, &owned)
}

pop_action :: proc(queue: ^Mailbox) -> (owned: ak.Owned_Action_Request, ok: bool) {
	win.AcquireSRWLockExclusive(&queue.lock)
	defer win.ReleaseSRWLockExclusive(&queue.lock)
	if queue.count == 0 { return }
	owned = queue.requests[queue.head]
	queue.requests[queue.head] = {}
	queue.head = (queue.head + 1) % len(queue.requests)
	queue.count -= 1
	return owned, true
}

close_mailbox :: proc(queue: ^Mailbox) {
	win.AcquireSRWLockExclusive(&queue.lock)
	queue.closed = true
	queue.hwnd = nil
	win.ReleaseSRWLockExclusive(&queue.lock)
	for {
		owned, ok := pop_action(queue)
		if !ok { break }
		ak.owned_action_request_destroy(&owned)
	}
}

apply_action :: proc(app: ^App, request: ^ak.Owned_Action_Request) {
	on_ui_thread(app)
	if request.target_node != BUTTON && request.target_node != FIELD { return }
	app.actions += 1
	switch request.action {
	case ak.ACTION_FOCUS:
		win.SetFocus(app.hwnd)
		set_focus(app, request.target_node)
	case ak.ACTION_CLICK:
		if request.target_node == BUTTON { press_button(app) }
	case ak.ACTION_SET_VALUE, ak.ACTION_REPLACE_SELECTED_TEXT:
		if request.target_node != FIELD || !request.has_data || request.data_tag != ak.ACTION_DATA_VALUE { return }
		old_anchor, old_caret := app.anchor, app.caret
		if request.action == ak.ACTION_SET_VALUE { app.anchor = 0; app.caret = app.length }
		if !replace_selection(app, request.text_value) { app.anchor = old_anchor; app.caret = old_caret }
	case ak.ACTION_SET_TEXT_SELECTION:
		if request.target_node != FIELD || !request.has_data || request.data_tag != ak.ACTION_DATA_SET_TEXT_SELECTION { return }
		// This pinned payload contains values only, no borrowed pointers.
		selection := transmute(ak.Text_Selection)request.payload.value
		if selection.anchor.node != u64(RUN) || selection.focus.node != u64(RUN) ||
		   selection.anchor.character_index > uint(app.length) || selection.focus.character_index > uint(app.length) { return }
		app.anchor = int(selection.anchor.character_index)
		move_caret(app, int(selection.focus.character_index), true)
	}
}

drain_actions :: proc(app: ^App) {
	// Bound a wakeup's work so continuous producers cannot starve WM_CLOSE.
	for _ in 0..<len(mailbox.requests) {
		owned, ok := pop_action(&mailbox)
		if !ok { break }
		apply_action(app, &owned) // Never hold the lock while raising UIA events.
		ak.owned_action_request_destroy(&owned)
	}
}
