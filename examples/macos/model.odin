package main

import "base:runtime"
import "core:fmt"
import "core:sync"
import "core:unicode/utf8"
import ak "accesskit:accesskit"

ROOT   :: ak.Node_ID(1)
BUTTON :: ak.Node_ID(2)
FIELD  :: ak.Node_ID(3)
RUN    :: ak.Node_ID(4)
MAX_TEXT :: 64
QUEUE_CAPACITY :: 32

// Matches host.h. Text positions count Unicode scalars, not UTF-8 bytes or
// UTF-16 code units. This small editor does not implement grapheme navigation.
KEY_TAB :: 1
KEY_RETURN :: 2
KEY_SPACE :: 3
KEY_BACKSPACE :: 4
KEY_DELETE :: 5
KEY_LEFT :: 6
KEY_RIGHT :: 7
KEY_HOME :: 8
KEY_END :: 9
KEY_SELECT_ALL :: 10

Snapshot :: struct {
	text: [MAX_TEXT]rune,
	length, anchor, caret: int,
	focus: ak.Node_ID,
	presses: u64,
}

Command :: struct {
	action: ak.Action,
	target: ak.Node_ID,
	has_data: bool,
	data_tag: ak.Action_Data_Tag,
	selection: ak.Text_Selection,
	text: [MAX_TEXT]rune,
	length: int,
}

// Shared callback data is separate from the UI-owned App. Fixed storage means
// no borrowed C text, per-thread allocators, or NSObjects cross this boundary.
// On macOS this bridge has process lifetime, including after adapter shutdown.
Bridge :: struct {
	mutex: sync.Mutex,
	accepting: bool,
	published: Snapshot,
	queue: [QUEUE_CAPACITY]Command,
	read, count: int,
	activations, factories, received, rejected: u64,
}

Encoded_Text :: struct {
	bytes: [MAX_TEXT * 4]u8,
	lengths: [MAX_TEXT]u8,
	length: int,
}

initial_snapshot :: proc() -> (s: Snapshot) {
	s.focus = BUTTON
	for r in "Hello, Odin 🦄" {
		s.text[s.length] = r
		s.length += 1
	}
	s.anchor, s.caret = s.length, s.length
	return
}

encode_text :: proc(s: ^Snapshot) -> (encoded: Encoded_Text) {
	for r, i in s.text[:s.length] {
		bytes, width := utf8.encode_rune(r)
		copy(encoded.bytes[encoded.length:], bytes[:width])
		encoded.length += width
		encoded.lengths[i] = u8(width)
	}
	return
}

button_label :: proc(s: ^Snapshot, buffer: []u8) -> string {
	return fmt.bprintf(buffer, "Press me (%d)", s.presses)
}

// Returns false rather than truncating an action or inserting line/control
// characters into this single-line editor. Empty strings intentionally work.
decode_text :: proc(value: string, destination: ^[MAX_TEXT]rune) -> (length: int, ok: bool) {
	if !utf8.valid_string(value) { return 0, false }
	for r in value {
		if length == MAX_TEXT || r < 32 || r == 127 { return 0, false }
		destination[length] = r
		length += 1
	}
	return length, true
}

command_from_view :: proc(view: ak.Borrowed_Action_Request) -> (command: Command, ok: bool) {
	command.action = view.action
	command.target = view.target_node
	command.has_data = view.has_data
	command.data_tag = view.data_tag
	if view.has_data && view.data_tag == ak.ACTION_DATA_VALUE {
		if view.text_value == nil { return command, false }
		command.length, ok = decode_text(string(view.text_value), &command.text)
		if !ok { return command, false }
	} else if view.has_data && view.data_tag == ak.ACTION_DATA_SET_TEXT_SELECTION {
		command.selection = transmute(ak.Text_Selection)view.payload.value
	}
	return command, true
}

enqueue :: proc(bridge: ^Bridge, command: Command) -> bool {
	sync.mutex_lock(&bridge.mutex)
	defer sync.mutex_unlock(&bridge.mutex)
	if !bridge.accepting || bridge.count == QUEUE_CAPACITY {
		bridge.rejected += 1
		return false
	}
	bridge.queue[(bridge.read + bridge.count) % QUEUE_CAPACITY] = command
	bridge.count += 1
	bridge.received += 1
	return true
}

enqueue_view :: proc(bridge: ^Bridge, view: ak.Borrowed_Action_Request) -> bool {
	command, ok := command_from_view(view)
	if !ok {
		sync.mutex_lock(&bridge.mutex)
		bridge.rejected += 1
		sync.mutex_unlock(&bridge.mutex)
		return false
	}
	return enqueue(bridge, command)
}

dequeue :: proc(bridge: ^Bridge) -> (command: Command, ok: bool) {
	sync.mutex_lock(&bridge.mutex)
	defer sync.mutex_unlock(&bridge.mutex)
	if bridge.count == 0 { return command, false }
	command = bridge.queue[bridge.read]
	bridge.queue[bridge.read] = {}
	bridge.read = (bridge.read + 1) % QUEUE_CAPACITY
	bridge.count -= 1
	return command, true
}

publish :: proc(bridge: ^Bridge, s: Snapshot) {
	sync.mutex_lock(&bridge.mutex)
	bridge.published = s
	sync.mutex_unlock(&bridge.mutex)
}

stop_accepting :: proc(bridge: ^Bridge) {
	sync.mutex_lock(&bridge.mutex)
	bridge.accepting = false
	bridge.queue = {}
	bridge.count, bridge.read = 0, 0
	sync.mutex_unlock(&bridge.mutex)
}

replace_selection :: proc(s: ^Snapshot, text: []rune) -> bool {
	lo, hi := min(s.anchor, s.caret), max(s.anchor, s.caret)
	new_length := s.length - (hi - lo) + len(text)
	if new_length > MAX_TEXT { return false }
	result: [MAX_TEXT]rune
	copy(result[:lo], s.text[:lo])
	copy(result[lo:], text)
	copy(result[lo + len(text):], s.text[hi:s.length])
	s.text, s.length = result, new_length
	s.anchor, s.caret = lo + len(text), lo + len(text)
	return true
}

apply_command :: proc(s: ^Snapshot, command: Command) -> bool {
	switch command.action {
	case ak.ACTION_FOCUS:
		if command.target != BUTTON && command.target != FIELD { return false }
		s.focus = command.target
	case ak.ACTION_CLICK:
		if command.target != BUTTON { return false }
		s.focus = BUTTON
		s.presses += 1
	case ak.ACTION_SET_VALUE, ak.ACTION_REPLACE_SELECTED_TEXT:
		if command.target != FIELD || !command.has_data || command.data_tag != ak.ACTION_DATA_VALUE { return false }
		if command.action == ak.ACTION_SET_VALUE { s.anchor, s.caret = 0, s.length }
		text := command.text
		if !replace_selection(s, text[:command.length]) { return false }
		s.focus = FIELD
	case ak.ACTION_SET_TEXT_SELECTION:
		if command.target != FIELD || !command.has_data || command.data_tag != ak.ACTION_DATA_SET_TEXT_SELECTION { return false }
		a, f := command.selection.anchor, command.selection.focus
		if a.node != u64(RUN) || f.node != u64(RUN) || a.character_index > uint(s.length) || f.character_index > uint(s.length) { return false }
		s.anchor, s.caret = int(a.character_index), int(f.character_index)
		s.focus = FIELD
	case:
		return false
	}
	return true
}

handle_key :: proc(s: ^Snapshot, key: int, shift: bool) -> bool {
	if key == KEY_TAB {
		s.focus = FIELD if s.focus == BUTTON else BUTTON
		return true
	}
	if s.focus == BUTTON {
		if key != KEY_SPACE && key != KEY_RETURN { return false }
		s.presses += 1
		return true
	}
	switch key {
	case KEY_SPACE:
		space := [1]rune{' '}
		return replace_selection(s, space[:])
	case KEY_BACKSPACE, KEY_DELETE:
		if s.anchor == s.caret {
			if key == KEY_BACKSPACE { s.anchor = max(0, s.caret - 1) }
			else { s.anchor = min(s.length, s.caret + 1) }
		}
		return replace_selection(s, nil)
	case KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END:
		if key == KEY_HOME { s.caret = 0 }
		else if key == KEY_END { s.caret = s.length }
		else if !shift && s.anchor != s.caret {
			s.caret = min(s.anchor, s.caret) if key == KEY_LEFT else max(s.anchor, s.caret)
		} else if key == KEY_LEFT { s.caret = max(0, s.caret - 1) }
		else { s.caret = min(s.length, s.caret + 1) }
		if !shift { s.anchor = s.caret }
	case KEY_SELECT_ALL:
		s.anchor, s.caret = 0, s.length
	case:
		return false
	}
	return true
}

// All four nodes are sent on every update to keep this example easy to follow.
// The C ownership wrappers clear each handle when transferring it to its parent.
build_update :: proc(snapshot: Snapshot, initial: bool) -> rawptr {
	s := snapshot
	root, root_ok := ak.node_create(ak.ROLE_WINDOW)
	assert(root_ok)
	defer ak.node_destroy(&root)
	button, button_ok := ak.node_create(ak.ROLE_BUTTON)
	assert(button_ok)
	defer ak.node_destroy(&button)
	field, field_ok := ak.node_create(ak.ROLE_TEXT_INPUT)
	assert(field_ok)
	defer ak.node_destroy(&field)
	run, run_ok := ak.node_create(ak.ROLE_TEXT_RUN)
	assert(run_ok)
	defer ak.node_destroy(&run)
	encoded := encode_text(&s)
	value := string(encoded.bytes[:encoded.length])
	label_buffer: [96]u8
	ak.node_set_label(&root, "Odin AccessKit native macOS example")
	ak.node_set_bounds(&root, {0, 0, 560, 260})
	ak.node_push_child(&root, BUTTON)
	ak.node_push_child(&root, FIELD)
	ak.node_set_label(&button, button_label(&s, label_buffer[:]))
	ak.node_set_bounds(&button, {24, 40, 284, 84})
	ak.node_add_action(&button, ak.ACTION_CLICK)
	ak.node_add_action(&button, ak.ACTION_FOCUS)
	ak.node_set_label(&field, "Message")
	ak.node_set_value(&field, value)
	ak.node_set_bounds(&field, {24, 140, 536, 182})
	ak.node_push_child(&field, RUN)
	field_actions := [4]ak.Action{ak.ACTION_FOCUS, ak.ACTION_SET_VALUE, ak.ACTION_REPLACE_SELECTED_TEXT, ak.ACTION_SET_TEXT_SELECTION}
	for action in field_actions {
		ak.node_add_action(&field, action)
	}
	ak.node_set_text_selection(&field, {
		anchor = {u64(RUN), uint(s.anchor)}, focus = {u64(RUN), uint(s.caret)},
	})
	ak.node_set_value(&run, value)
	ak.node_set_bounds(&run, {36, 148, 524, 172})
	// A non-nil backing pointer also for the empty run: Rust's zero-length
	// slice FFI still requires a non-null pointer. No binding edits are needed.
	ak.accesskit_node_set_character_lengths(run.raw, uint(s.length), rawptr(&encoded.lengths[0]))
	update, update_ok := ak.tree_update_create(4, s.focus)
	assert(update_ok)
	defer ak.tree_update_destroy(&update)
	if initial {
		tree, tree_ok := ak.tree_info_create(ROOT)
		assert(tree_ok)
		defer ak.tree_info_destroy(&tree)
		ak.tree_info_set_toolkit_name(&tree, "Standalone Odin/AppKit example")
		assert(ak.tree_update_set_tree_info(&update, &tree))
	}
	assert(ak.tree_update_push_node(&update, ROOT, &root))
	assert(ak.tree_update_push_node(&update, BUTTON, &button))
	assert(ak.tree_update_push_node(&update, FIELD, &field))
	assert(ak.tree_update_push_node(&update, RUN, &run))
	return ak.tree_update_take(&update)
}

activation_callback :: proc "c" (userdata: rawptr) -> rawptr {
	context = runtime.default_context()
	bridge := cast(^Bridge)userdata
	sync.mutex_lock(&bridge.mutex)
	snapshot := bridge.published
	bridge.activations += 1
	sync.mutex_unlock(&bridge.mutex)
	// Even late activation during teardown gets an owned, non-nil snapshot.
	return build_update(snapshot, true)
}

update_factory :: proc "c" (userdata: rawptr) -> rawptr {
	context = runtime.default_context()
	bridge := cast(^Bridge)userdata
	sync.mutex_lock(&bridge.mutex)
	snapshot := bridge.published
	bridge.factories += 1
	sync.mutex_unlock(&bridge.mutex)
	return build_update(snapshot, false)
}

action_callback :: proc "c" (raw_request: rawptr, userdata: rawptr) {
	context = runtime.default_context()
	request := ak.action_request_take(raw_request)
	defer ak.action_request_destroy(&request)
	view, ok := ak.action_request_borrow(&request)
	if ok { enqueue_view(cast(^Bridge)userdata, view) }
	// Only synchronized transport changed. The UI applies the copied command.
}
