package main

import "base:runtime"
import "core:fmt"
import "core:time"
import win "core:sys/windows"
import ak "accesskit:accesskit"

// Exercise the same copy/mailbox path on a real foreign thread without
// inventing a Rust-owned C request (only AccessKit can allocate those).
smoke_worker :: proc "system" (userdata: rawptr) -> win.DWORD {
	context = runtime.default_context()
	queue := cast(^Mailbox)userdata
	views := [5]ak.Borrowed_Action_Request{
		{action = ak.ACTION_FOCUS, target_node = FIELD},
		{action = ak.ACTION_SET_VALUE, target_node = FIELD, has_data = true, data_tag = ak.ACTION_DATA_VALUE, text_value = "Odin 🦄"},
		{action = ak.ACTION_SET_TEXT_SELECTION, target_node = FIELD, has_data = true, data_tag = ak.ACTION_DATA_SET_TEXT_SELECTION},
		{action = ak.ACTION_REPLACE_SELECTED_TEXT, target_node = FIELD, has_data = true, data_tag = ak.ACTION_DATA_VALUE, text_value = "Native"},
		{action = ak.ACTION_CLICK, target_node = BUTTON},
	}
	views[2].payload.value = transmute([4]u64)ak.Text_Selection{{u64(RUN), 0}, {u64(RUN), 4}}
	for view in views {
		owned, ok := ak.action_request_copy(view, context.allocator)
		if !ok { ak.owned_action_request_destroy(&owned); return 1 }
		enqueue(queue, &owned)
	}
	return 0
}

start_smoke :: proc(app: ^App) -> bool {
	app.smoke_start = time.tick_now()
	// Request the actual UIA provider through AccessKit's HWND subclass. This
	// forces activation even on CI machines without a screen reader attached.
	win.SendMessageW(app.hwnd, win.WM_GETOBJECT, 0, -25) // UiaRootObjectId
	if win.SetTimer(app.hwnd, 1, 50, nil) == 0 {
		fmt.eprintln("SMOKE FAIL: SetTimer failed")
		return false
	}
	app.worker = win.CreateThread(nil, 0, smoke_worker, &mailbox, 0, nil)
	if app.worker == nil { fmt.eprintln("SMOKE FAIL: CreateThread failed"); return false }
	return true
}

smoke_tick :: proc(app: ^App) {
	if time.tick_since(app.smoke_start) > 3 * time.Second {
		fmt.eprintln("SMOKE FAIL: 3-second deadline exceeded")
		app.exit_code = 1
		close_window(app)
		return
	}
	if app.actions < 5 || win.WaitForSingleObject(app.worker, 0) != win.WAIT_OBJECT_0 { return }
	text := encode_text(app)
	ok := string(text.bytes[:text.length]) == "Native 🦄" && app.presses == 1 && app.focus == BUTTON &&
		app.activations > 0 && app.focus_updates > 0 && app.selection_updates > 0 && app.text_updates >= 2 && app.status_updates > 0
	// Route keyboard editing through the real WndProc, including a surrogate
	// pair and deleting one full scalar rather than half its UTF-16 encoding.
	win.SendMessageW(app.hwnd, win.WM_KEYDOWN, win.VK_TAB, 0)
	win.SendMessageW(app.hwnd, win.WM_KEYDOWN, win.VK_END, 0)
	win.SendMessageW(app.hwnd, win.WM_CHAR, 0xd83e, 0)
	win.SendMessageW(app.hwnd, win.WM_CHAR, 0xdd84, 0)
	win.SendMessageW(app.hwnd, win.WM_CHAR, 8, 0)
	text = encode_text(app)
	ok = ok && app.focus == FIELD && string(text.bytes[:text.length]) == "Native 🦄"
	win.AcquireSRWLockExclusive(&mailbox.lock)
	ok = ok && mailbox.count == 0 && mailbox.rejected == 0
	win.ReleaseSRWLockExclusive(&mailbox.lock)
	if ok {
		fmt.printf("SMOKE PASS: activation=%d actions=%d incremental=%d; worker queue, Unicode editing, focus, shutdown\n", app.activations, app.actions, app.updates)
	} else {
		fmt.eprintf("SMOKE FAIL: activation=%d actions=%d updates=%d text=%q\n", app.activations, app.actions, app.updates, string(text.bytes[:text.length]))
		app.exit_code = 1
	}
	close_window(app)
}
