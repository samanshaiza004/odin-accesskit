package main

import "core:testing"
import "core:thread"
import ak "accesskit:accesskit"

@(test)
unicode_selection_and_updates :: proc(t: ^testing.T) {
	s := initial_snapshot()
	mailbox := Bridge{accepting = true, published = s}
	initial := ak.Tree_Update{raw = activation_callback(&mailbox)}
	testing.expect(t, initial.raw != nil)
	ak.tree_update_destroy(&initial)
	view := ak.Borrowed_Action_Request{
		action = ak.ACTION_SET_VALUE, target_node = FIELD,
		has_data = true, data_tag = ak.ACTION_DATA_VALUE, text_value = "Odin 🦄",
	}
	testing.expect(t, enqueue_view(&mailbox, view))
	command, available := dequeue(&mailbox)
	testing.expect(t, available && apply_command(&s, command))
	testing.expect(t, s.length == 6 && s.caret == 6)
	selection := Command{
		action = ak.ACTION_SET_TEXT_SELECTION, target = FIELD,
		has_data = true, data_tag = ak.ACTION_DATA_SET_TEXT_SELECTION,
		selection = {{u64(RUN), 4}, {u64(RUN), 0}}, // reversed selection
	}
	testing.expect(t, apply_command(&s, selection))
	view.action, view.text_value = ak.ACTION_REPLACE_SELECTED_TEXT, "Native"
	replacement, ok := command_from_view(view)
	testing.expect(t, ok && apply_command(&s, replacement))
	encoded := encode_text(&s)
	testing.expect(t, string(encoded.bytes[:encoded.length]) == "Native 🦄")
	testing.expect(t, encoded.lengths[s.length - 1] == 4)
	selection.selection.focus.character_index = 1000
	before := s
	testing.expect(t, !apply_command(&s, selection) && s == before)
	testing.expect(t, handle_key(&s, KEY_END, false))
	testing.expect(t, handle_key(&s, KEY_BACKSPACE, false))
	encoded = encode_text(&s)
	testing.expect(t, string(encoded.bytes[:encoded.length]) == "Native ")
	testing.expect(t, handle_key(&s, KEY_SELECT_ALL, false))
	testing.expect(t, handle_key(&s, KEY_DELETE, false))
	testing.expect(t, s.length == 0 && s.caret == 0)
	publish(&mailbox, s)
	update := ak.Tree_Update{raw = update_factory(&mailbox)}
	testing.expect(t, update.raw != nil)
	ak.tree_update_destroy(&update)
}

@(test)
bounded_mailbox_and_shutdown :: proc(t: ^testing.T) {
	mailbox := Bridge{accepting = true, published = initial_snapshot()}
	command := Command{action = ak.ACTION_CLICK, target = BUTTON}
	for _ in 0..<QUEUE_CAPACITY { testing.expect(t, enqueue(&mailbox, command)) }
	testing.expect(t, !enqueue(&mailbox, command))
	for _ in 0..<QUEUE_CAPACITY {
		dequeued, ok := dequeue(&mailbox)
		testing.expect(t, ok && dequeued.action == ak.ACTION_CLICK)
	}
	_, empty := dequeue(&mailbox)
	testing.expect(t, !empty)
	stop_accepting(&mailbox)
	testing.expect(t, !enqueue(&mailbox, command) && mailbox.rejected == 2)
	late := ak.Tree_Update{raw = activation_callback(&mailbox)}
	testing.expect(t, late.raw != nil)
	ak.tree_update_destroy(&late)
	// Reject wrong payload tags and out-of-range native targets.
	s := initial_snapshot()
	testing.expect(t, !apply_command(&s, {action = ak.ACTION_SET_VALUE, target = FIELD}))
	testing.expect(t, !apply_command(&s, {action = ak.ACTION_FOCUS, target = RUN}))
	runes: [MAX_TEXT]rune
	_, valid := decode_text("first\nsecond", &runes)
	testing.expect(t, !valid)
}

test_producer :: proc(data: rawptr) {
	mailbox := cast(^Bridge)data
	// Borrowed bytes are changed after enqueue, proving the queue owns a copy.
	text := [5]u8{'O', 'd', 'i', 'n', 0}
	view := ak.Borrowed_Action_Request{
		action = ak.ACTION_SET_VALUE, target_node = FIELD,
		has_data = true, data_tag = ak.ACTION_DATA_VALUE,
		text_value = cast(cstring)&text[0],
	}
	enqueue_view(mailbox, view)
	text[0] = 'X'
}

@(test)
worker_only_transports_copied_actions :: proc(t: ^testing.T) {
	s := initial_snapshot()
	mailbox := Bridge{accepting = true, published = s}
	worker := thread.create_and_start_with_data(&mailbox, test_producer)
	thread.join(worker)
	thread.destroy(worker)
	testing.expect(t, s == initial_snapshot() && mailbox.published == s)
	command, ok := dequeue(&mailbox)
	testing.expect(t, ok && apply_command(&s, command))
	encoded := encode_text(&s)
	testing.expect(t, string(encoded.bytes[:encoded.length]) == "Odin")
}
