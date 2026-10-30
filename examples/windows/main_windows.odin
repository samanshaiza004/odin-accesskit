package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:time"
import "core:unicode/utf8"
import win "core:sys/windows"
import ak "accesskit:accesskit"

ROOT   :: ak.Node_ID(1)
BUTTON :: ak.Node_ID(2)
FIELD  :: ak.Node_ID(3)
RUN    :: ak.Node_ID(4)
STATUS :: ak.Node_ID(5)
MAX_CHARACTERS :: 256
ACTION_MESSAGE :: win.WM_APP + 1
CLASS_NAME := cstring16(win.L("OdinAccessKitNativeExample"))
TITLE := cstring16(win.L("AccessKit Odin - native Windows example"))
BUTTON_RECT :: win.RECT{24, 50, 224, 94}
FIELD_RECT :: win.RECT{24, 138, 536, 180}

App :: struct {
	hwnd: win.HWND,
	adapter: ak.Windows_Subclassing_Adapter,
	ui_thread: win.DWORD,
	focus: ak.Node_ID,
	window_focused: bool,
	text: [MAX_CHARACTERS]rune,
	length, anchor, caret: int,
	high_surrogate: u16,
	presses, actions, activations, updates: int,
	full_updates, selection_updates, focus_updates, text_updates, status_updates: int,
	closing: bool,
	exit_code: i32,
	smoke: bool,
	smoke_start: time.Tick,
	worker: win.HANDLE,
}

// Every App access, including activation/update factories, is on this thread.
on_ui_thread :: proc(app: ^App) {
	assert(win.GetCurrentThreadId() == app.ui_thread)
}

Encoded_Text :: struct {
	bytes: [MAX_CHARACTERS * 4]u8,
	lengths: [MAX_CHARACTERS]u8,
	length: int,
}

encode_text :: proc(app: ^App, start: int = 0, end: int = -1) -> Encoded_Text {
	result: Encoded_Text
	end := end
	if end < 0 { end = app.length }
	for i in start..<end {
		bytes, count := utf8.encode_rune(app.text[i])
		copy(result.bytes[result.length:], bytes[:count])
		result.lengths[i - start] = u8(count)
		result.length += count
	}
	return result
}

// Atomic from the editor's perspective: reject invalid UTF-8, line breaks,
// control characters, or an over-capacity edit without changing the selection.
replace_selection :: proc(app: ^App, value: string) -> bool {
	if !utf8.valid_string(value) { return false }
	insert: [MAX_CHARACTERS]rune
	count := 0
	for r in value {
		if r < ' ' || (r >= 0x7f && r < 0xa0) || r == 0x2028 || r == 0x2029 || count == MAX_CHARACTERS {
			return false
		}
		insert[count] = r
		count += 1
	}
	lo, hi := min(app.anchor, app.caret), max(app.anchor, app.caret)
	if app.length - (hi - lo) + count > MAX_CHARACTERS { return false }
	tail: [MAX_CHARACTERS]rune
	tail_length := app.length - hi
	copy(tail[:], app.text[hi:app.length])
	copy(app.text[lo:], insert[:count])
	copy(app.text[lo + count:], tail[:tail_length])
	app.length = lo + count + tail_length
	app.caret = lo + count
	app.anchor = app.caret
	publish(app, {.Field, .Run})
	return true
}

set_focus :: proc(app: ^App, focus: ak.Node_ID) {
	on_ui_thread(app)
	if focus != BUTTON && focus != FIELD { return }
	app.high_surrogate = 0
	app.focus = focus
	publish(app, {}) // Focus alone needs no replacement nodes.
}

press_button :: proc(app: ^App) {
	on_ui_thread(app)
	app.focus = BUTTON
	app.presses += 1
	publish(app, {.Status})
}

move_caret :: proc(app: ^App, position: int, extend: bool) {
	app.caret = clamp(position, 0, app.length)
	if !extend { app.anchor = app.caret }
	app.high_surrogate = 0
	publish(app, {.Field}) // Selection changes do not replace the TextRun.
}

key_down :: proc(app: ^App, key: win.WPARAM) -> bool {
	shift := win.GetKeyState(win.VK_SHIFT) < 0
	control := win.GetKeyState(win.VK_CONTROL) < 0
	switch key {
	case win.VK_ESCAPE:
		close_window(app)
	case win.VK_TAB:
		if app.focus == BUTTON { set_focus(app, FIELD) } else { set_focus(app, BUTTON) }
	case win.VK_SPACE, win.VK_RETURN:
		if app.focus == BUTTON { press_button(app) }
	case:
		if app.focus != FIELD { return false }
		switch key {
		case 'A':
			if !control { return false }
			app.anchor = 0
			move_caret(app, app.length, true)
		case win.VK_LEFT:
			position := app.caret - 1
			if !shift && app.anchor != app.caret { position = min(app.anchor, app.caret) }
			move_caret(app, position, shift)
		case win.VK_RIGHT:
			position := app.caret + 1
			if !shift && app.anchor != app.caret { position = max(app.anchor, app.caret) }
			move_caret(app, position, shift)
		case win.VK_HOME: move_caret(app, 0, shift)
		case win.VK_END: move_caret(app, app.length, shift)
		case win.VK_DELETE:
			app.high_surrogate = 0
			if app.anchor == app.caret && app.caret < app.length { app.anchor += 1 }
			if app.anchor != app.caret { replace_selection(app, "") }
		case: return false
		}
	}
	return true
}

character :: proc(app: ^App, unit: u16) {
	if app.focus != FIELD { return }
	if unit == 8 {
		app.high_surrogate = 0
		if app.anchor == app.caret && app.caret > 0 { app.anchor -= 1 }
		if app.anchor != app.caret { replace_selection(app, "") }
		return
	}
	if unit < 32 || unit == 127 { app.high_surrogate = 0; return }
	if unit >= 0xd800 && unit <= 0xdbff { app.high_surrogate = unit; return }
	r := rune(unit)
	if unit >= 0xdc00 && unit <= 0xdfff {
		if app.high_surrogate == 0 { return }
		r = 0x10000 + (rune(app.high_surrogate) - 0xd800) * 0x400 + (rune(unit) - 0xdc00)
	}
	app.high_surrogate = 0
	bytes, count := utf8.encode_rune(r)
	replace_selection(app, string(bytes[:count]))
}

// Keep userdata and its SRW lock alive for the process lifetime: an external
// UIA provider can retain the action handler even after the adapter is freed.
close_window :: proc(app: ^App) {
	on_ui_thread(app)
	if app.closing { return }
	app.closing = true
	close_mailbox(&mailbox)
	win.KillTimer(app.hwnd, 1)
	ak.windows_subclassing_adapter_destroy(&app.adapter)
	win.DestroyWindow(app.hwnd)
}

window_proc :: proc "system" (hwnd: win.HWND, message: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	context = runtime.default_context()
	if message == win.WM_NCCREATE {
		create := cast(^win.CREATESTRUCTW)uintptr(lparam)
		app := cast(^App)create.lpCreateParams
		app.hwnd = hwnd
		win.SetWindowLongPtrW(hwnd, win.GWLP_USERDATA, win.LONG_PTR(uintptr(app)))
	}
	app := cast(^App)uintptr(win.GetWindowLongPtrW(hwnd, win.GWLP_USERDATA))
	if app == nil { return win.DefWindowProcW(hwnd, message, wparam, lparam) }
	on_ui_thread(app)
	switch message {
	case win.WM_PAINT: paint(app)
	case win.WM_SETFOCUS, win.WM_KILLFOCUS:
		// The subclassing adapter forwards native focus messages itself.
		app.window_focused = message == win.WM_SETFOCUS
		if !app.window_focused { app.high_surrogate = 0 }
		win.InvalidateRect(hwnd, nil, false)
	case win.WM_SIZE:
		if !app.closing { publish(app, {.Root}) }
	case win.WM_GETMINMAXINFO:
		limits := cast(^win.MINMAXINFO)uintptr(lparam)
		limits.ptMinTrackSize = {580, 320}
	case win.WM_KEYDOWN:
		if !key_down(app, wparam) { return win.DefWindowProcW(hwnd, message, wparam, lparam) }
	case win.WM_CHAR: character(app, u16(wparam))
	case win.WM_LBUTTONDOWN:
		win.SetFocus(hwnd)
		x, y := win.GET_X_LPARAM(lparam), win.GET_Y_LPARAM(lparam)
		if contains(BUTTON_RECT, x, y) { press_button(app) }
		if contains(FIELD_RECT, x, y) {
			set_focus(app, FIELD)
			move_caret(app, app.length, false)
		}
	case ACTION_MESSAGE:
		if !app.closing { drain_actions(app) }
	case win.WM_TIMER:
		if app.smoke { smoke_tick(app) }
	case win.WM_CLOSE: close_window(app)
	case win.WM_DESTROY:
		// Also cover destruction initiated by the OS, not only WM_CLOSE.
		if !app.closing {
			app.closing = true
			close_mailbox(&mailbox)
			ak.windows_subclassing_adapter_destroy(&app.adapter)
		}
		win.PostQuitMessage(app.exit_code)
	case win.WM_NCDESTROY:
		win.SetWindowLongPtrW(hwnd, win.GWLP_USERDATA, 0)
		return win.DefWindowProcW(hwnd, message, wparam, lparam)
	case: return win.DefWindowProcW(hwnd, message, wparam, lparam)
	}
	return 0
}

contains :: proc(rect: win.RECT, x, y: i32) -> bool {
	return x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom
}

draw_text :: proc(dc: win.HDC, value: string, rect: win.RECT) {
	wide := win.utf8_to_utf16(value, context.allocator)
	defer delete(wide)
	if len(wide) == 0 { return }
	r := rect
	win.DrawTextW(dc, cstring16(raw_data(wide)), i32(len(wide)), &r, .DT_LEFT | .DT_SINGLELINE | .DT_VCENTER | .DT_NOPREFIX)
}

text_width :: proc(dc: win.HDC, app: ^App, start, end: int) -> i32 {
	encoded := encode_text(app, start, end)
	wide := win.utf8_to_utf16(string(encoded.bytes[:encoded.length]), context.allocator)
	defer delete(wide)
	size: win.SIZE
	if len(wide) > 0 { win.GetTextExtentPoint32W(dc, cstring16(raw_data(wide)), i32(len(wide)), &size) }
	return size.cx
}

paint :: proc(app: ^App) {
	ps: win.PAINTSTRUCT
	dc := win.BeginPaint(app.hwnd, &ps)
	defer win.EndPaint(app.hwnd, &ps)
	previous_font := win.SelectObject(dc, win.GetStockObject(win.DEFAULT_GUI_FONT))
	defer win.SelectObject(dc, previous_font)
	win.SetBkMode(dc, .TRANSPARENT)
	win.SetTextColor(dc, win.GetSysColor(win.COLOR_WINDOWTEXT))
	client: win.RECT
	win.GetClientRect(app.hwnd, &client)
	win.FillRect(dc, &client, win.GetSysColorBrush(win.COLOR_WINDOW))
	draw_text(dc, "AccessKit 0.23.1 / Odin / Win32 + GDI", {24, 10, 540, 40})
	button_rect := BUTTON_RECT
	win.FillRect(dc, &button_rect, win.GetSysColorBrush(win.COLOR_BTNFACE))
	win.FrameRect(dc, &button_rect, win.GetSysColorBrush(win.COLOR_WINDOWTEXT))
	draw_text(dc, "Press me", {40, 50, 208, 94})
	draw_text(dc, "Message (editable)", {24, 104, 536, 132})
	field_rect := FIELD_RECT
	win.FrameRect(dc, &field_rect, win.GetSysColorBrush(win.COLOR_WINDOWTEXT))
	if app.window_focused {
		focus_rect := BUTTON_RECT
		if app.focus == FIELD { focus_rect = FIELD_RECT }
		focus_rect.left -= 3; focus_rect.right += 3
		focus_rect.top -= 3; focus_rect.bottom += 3
		win.FrameRect(dc, &focus_rect, win.GetSysColorBrush(win.COLOR_HIGHLIGHT))
	}
	// Scroll the visible prefix to keep the caret in view. DrawText clips the
	// trailing text to the field; selection/caret geometry uses the same font.
	start := 0
	for start < app.caret && text_width(dc, app, start, app.caret) > 486 { start += 1 }
	visible := encode_text(app, start)
	if app.focus == FIELD && app.window_focused {
		lo, hi := min(app.anchor, app.caret), max(app.anchor, app.caret)
		left := 32 + text_width(dc, app, start, max(start, lo))
		right := min(i32(528), 32 + text_width(dc, app, start, max(start, hi)))
		if left < right {
			selection := win.RECT{left, 146, right, 172}
			win.FillRect(dc, &selection, win.GetSysColorBrush(win.COLOR_BTNFACE))
		}
		caret_x := 32 + text_width(dc, app, start, app.caret)
		caret_rect := win.RECT{caret_x, 146, caret_x + 1, 172}
		win.FillRect(dc, &caret_rect, win.GetSysColorBrush(win.COLOR_WINDOWTEXT))
	}
	draw_text(dc, string(visible.bytes[:visible.length]), {32, 138, 528, 180})
	status_buffer: [80]u8
	draw_text(dc, fmt.bprintf(status_buffer[:], "Button pressed %d time(s)", app.presses), {24, 190, 536, 218})
	draw_text(dc, "Tab: focus   Space/Enter: press   Esc: close", {24, 228, 556, 250})
	draw_text(dc, "Edit: arrows, Home/End, Shift, Ctrl+A, Backspace/Delete", {24, 250, 556, 272})
}

run :: proc() -> i32 {
	app := App{ui_thread = win.GetCurrentThreadId(), focus = BUTTON}
	for arg in os.args[1:] {
		if arg == "--smoke" { app.smoke = true } else {
			fmt.eprintln("Usage: windows-example.exe [--smoke]")
			return 2
		}
	}
	for r in "Hello, AccessKit!" { app.text[app.length] = r; app.length += 1 }
	app.anchor = app.length; app.caret = app.length
	instance := win.HINSTANCE(win.GetModuleHandleW(nil))
	wc := win.WNDCLASSEXW{
		cbSize = size_of(win.WNDCLASSEXW),
		lpfnWndProc = window_proc,
		hInstance = instance,
		hCursor = win.LoadCursorA(nil, win.IDC_ARROW),
		lpszClassName = CLASS_NAME,
	}
	if win.RegisterClassExW(&wc) == 0 { fmt.eprintln("RegisterClassExW failed"); return 1 }
	defer win.UnregisterClassW(CLASS_NAME, instance)
	// Deliberately omit WS_VISIBLE. AccessKit must subclass before ShowWindow.
	hwnd := win.CreateWindowExW(0, CLASS_NAME, TITLE, win.WS_OVERLAPPEDWINDOW,
		win.CW_USEDEFAULT, win.CW_USEDEFAULT, 600, 340, nil, nil, instance, &app)
	if hwnd == nil { fmt.eprintln("CreateWindowExW failed"); return 1 }
	defer { if !app.closing { close_window(&app) } }
	win.AcquireSRWLockExclusive(&mailbox.lock)
	mailbox.hwnd = hwnd
	win.ReleaseSRWLockExclusive(&mailbox.lock)
	adapter, ok := ak.windows_subclassing_adapter_create(rawptr(hwnd), activate, &app, action_callback, &mailbox)
	if !ok { fmt.eprintln("AccessKit adapter creation failed"); return 1 }
	app.adapter = adapter
	win.ShowWindow(hwnd, win.SW_SHOW)
	win.UpdateWindow(hwnd)
	if app.smoke && !start_smoke(&app) { return 1 }
	message: win.MSG
	for {
		result := win.GetMessageW(&message, nil, 0, 0)
		if result == -1 { app.exit_code = 1; break }
		if result == 0 { break }
		win.TranslateMessage(&message)
		win.DispatchMessageW(&message)
	}
	if app.worker != nil {
		// The worker only copies/posts five requests; it never waits on the UI.
		if win.WaitForSingleObject(app.worker, 1000) != win.WAIT_OBJECT_0 { app.exit_code = 1 }
		win.CloseHandle(app.worker)
	}
	return app.exit_code
}

main :: proc() { os.exit(int(run())) }
