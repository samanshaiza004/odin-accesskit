package accesskit

import "core:c/libc"
import "core:testing"

when ODIN_OS == .Windows {
	foreign import abi_probe "system:odin_accesskit_abi_probe.lib"
} else {
	foreign import abi_probe "system:odin_accesskit_abi_probe"
}
foreign abi_probe {
	accesskit_abi_rect_round_trip :: proc "c" (value: Rect) -> Rect ---
	accesskit_abi_text_selection_round_trip :: proc "c" (value: Text_Selection) -> Text_Selection ---
}

@(test)
test_odin_c_aggregate_abi_round_trip :: proc(t: ^testing.T) {
	expected_rect := Rect{x0 = 1.25, y0 = -2.5, x1 = 640, y1 = 480.5}
	actual_rect := accesskit_abi_rect_round_trip(expected_rect)
	testing.expect(t,
		actual_rect.x0 == expected_rect.x0 &&
		actual_rect.y0 == expected_rect.y0 &&
		actual_rect.x1 == expected_rect.x1 &&
		actual_rect.y1 == expected_rect.y1,
		"Odin-to-C aggregate argument and C-to-Odin aggregate return must preserve Rect fields")

	expected_selection := Text_Selection{
		anchor = Text_Position{node = 0x0102030405060708, character_index = 17},
		focus = Text_Position{node = 0x1112131415161718, character_index = 29},
	}
	actual_selection := accesskit_abi_text_selection_round_trip(expected_selection)
	testing.expect(t,
		actual_selection.anchor.node == expected_selection.anchor.node &&
		actual_selection.anchor.character_index == expected_selection.anchor.character_index &&
		actual_selection.focus.node == expected_selection.focus.node &&
		actual_selection.focus.character_index == expected_selection.focus.character_index,
		"Odin-to-C aggregate argument and C-to-Odin aggregate return must preserve text selection fields")
}

@(test)
test_node_text_is_owned_by_accesskit_after_setter_returns :: proc(t: ^testing.T) {
	node, ok := node_create(ROLE_BUTTON)
	testing.expect(t, ok, "AccessKit should allocate a node")
	defer node_destroy(&node)

	bytes := [5]u8{'A', 'p', 'p', 'l', 'y'}
	node_set_label(&node, string(bytes[:]))
	bytes[0] = 'X'

	label := accesskit_node_label(node.raw)
	if label == nil {
		testing.expect(t, false, "AccessKit should return the node label")
		return
	}
	defer accesskit_string_free(label)
	testing.expect(
		t,
		libc.strcmp(label, cstring("Apply")) == 0,
		"node text setters should retain their own copy of the supplied bytes",
	)

	node_set_label(&node, "")
	empty_label := accesskit_node_label(node.raw)
	if empty_label == nil {
		testing.expect(t, false, "an explicitly empty label should remain present")
		return
	}
	defer accesskit_string_free(empty_label)
	testing.expect(
		t,
		libc.strcmp(empty_label, cstring("")) == 0,
		"empty text should be passed with a valid zero-length C string slice",
	)
}

@(test)
test_node_action_and_tree_update_transfer_ownership :: proc(t: ^testing.T) {
	root, root_ok := node_create(ROLE_WINDOW)
	button, button_ok := node_create(ROLE_BUTTON)
	testing.expect(t, root_ok && button_ok, "AccessKit should allocate both nodes")
	defer node_destroy(&root)
	defer node_destroy(&button)

	node_push_child(&root, Node_ID(2))
	node_add_action(&button, ACTION_CLICK)
	testing.expect(
		t,
		node_supports_action(&button, ACTION_CLICK),
		"the typed action should reach AccessKit's node",
	)
	node_set_label(&button, "Apply changes")
	node_set_value(&button, "Ready")
	node_set_description(&button, "Applies the current changes")
	node_set_bounds(&button, Rect{12, 24, 112, 56})
	node_set_disabled(&button, true)
	node_set_selected(&button, true)
	node_set_expanded(&button, false)

	tree, tree_ok := tree_info_create(Node_ID(1))
	testing.expect(t, tree_ok, "AccessKit should allocate tree info")
	defer tree_info_destroy(&tree)
	tree_info_set_toolkit_name(&tree, "Odin fixture")
	tree_info_set_toolkit_version(&tree, "0.1")

	update, update_ok := tree_update_create(2, Node_ID(1))
	testing.expect(t, update_ok, "AccessKit should allocate a tree update")
	defer tree_update_destroy(&update)
	testing.expect(t, tree_update_set_tree_info(&update, &tree), "tree info should transfer")
	testing.expect(t, tree.raw == nil, "transferred tree info handle should be cleared")
	testing.expect(t, tree_update_push_node(&update, Node_ID(1), &root), "root should transfer")
	testing.expect(t, root.raw == nil, "transferred root handle should be cleared")
	testing.expect(t, tree_update_push_node(&update, Node_ID(2), &button), "button should transfer")
	testing.expect(t, button.raw == nil, "transferred button handle should be cleared")

	// Taking the update is the handoff used by a native adapter. Free it here
	// through the pinned C API to verify the transfer also clears the Odin handle.
	raw_update := tree_update_take(&update)
	testing.expect(t, raw_update != nil, "taking the update should return its C handle")
	testing.expect(t, update.raw == nil, "transferred update handle should be cleared")
	if raw_update != nil { accesskit_tree_update_free(raw_update) }
}

@(test)
test_common_role_values_match_accesskit_0_23_1 :: proc(t: ^testing.T) {
	testing.expect(t, u8(ROLE_LIST_BOX) == 87, "list box role must match pinned AccessKit 0.23.1")
	testing.expect(t, u8(ROLE_LIST_BOX_OPTION) == 10, "list box option role must match pinned AccessKit 0.23.1")
	testing.expect(t, u8(ROLE_STATUS) == 116, "status role must match pinned AccessKit 0.23.1")
}

@(test)
test_node_setter_enum_values_match_accesskit_0_23_1 :: proc(t: ^testing.T) {
	testing.expect(t, u8(LIVE_OFF) == 0, "live off value must match AccessKit 0.23.1")
	testing.expect(t, u8(LIVE_POLITE) == 1, "live polite value must match AccessKit 0.23.1")
	testing.expect(t, u8(LIVE_ASSERTIVE) == 2, "live assertive value must match AccessKit 0.23.1")
	testing.expect(t, u8(TOGGLED_FALSE) == 0, "toggled false value must match AccessKit 0.23.1")
	testing.expect(t, u8(TOGGLED_TRUE) == 1, "toggled true value must match AccessKit 0.23.1")
	testing.expect(t, u8(TOGGLED_MIXED) == 2, "toggled mixed value must match AccessKit 0.23.1")
	testing.expect(t, u8(INVALID_TRUE) == 0, "invalid true value must match AccessKit 0.23.1")
	testing.expect(t, u8(INVALID_GRAMMAR) == 1, "invalid grammar value must match AccessKit 0.23.1")
	testing.expect(t, u8(INVALID_SPELLING) == 2, "invalid spelling value must match AccessKit 0.23.1")
	testing.expect(t, u8(ARIA_CURRENT_FALSE) == 0, "current false value must match AccessKit 0.23.1")
	testing.expect(t, u8(ARIA_CURRENT_TRUE) == 1, "current true value must match AccessKit 0.23.1")
	testing.expect(t, u8(ARIA_CURRENT_PAGE) == 2, "current page value must match AccessKit 0.23.1")
	testing.expect(t, u8(ARIA_CURRENT_STEP) == 3, "current step value must match AccessKit 0.23.1")
	testing.expect(t, u8(ARIA_CURRENT_LOCATION) == 4, "current location value must match AccessKit 0.23.1")
	testing.expect(t, u8(ARIA_CURRENT_DATE) == 5, "current date value must match AccessKit 0.23.1")
	testing.expect(t, u8(ARIA_CURRENT_TIME) == 6, "current time value must match AccessKit 0.23.1")
}

@(test)
test_typed_node_setters_reach_accesskit :: proc(t: ^testing.T) {
	node, ok := node_create(ROLE_TEXT_INPUT)
	testing.expect(t, ok, "AccessKit should allocate a text-input node")
	if !ok { return }
	defer node_destroy(&node)

	character_lengths := [3]u8{2, 3, 4}
	node_set_character_lengths(&node, character_lengths[:])
	node_set_text_selection(&node, Text_Selection{
		anchor = Text_Position{node = 7, character_index = 1},
		focus = Text_Position{node = 7, character_index = 2},
	})
	node_set_live(&node, LIVE_POLITE)
	node_set_live_atomic(&node)
	node_set_required(&node)
	node_set_read_only(&node)
	node_set_invalid(&node, INVALID_GRAMMAR)
	node_set_busy(&node)
	node_set_aria_current(&node, ARIA_CURRENT_PAGE)
	node_set_toggled(&node, TOGGLED_TRUE)
	node_set_position_in_set(&node, 2)
	node_set_size_of_set(&node, 5)
	node_set_min_numeric_value(&node, 0)
	node_set_max_numeric_value(&node, 10)
	node_set_numeric_value(&node, 4)
	node_set_numeric_value_step(&node, 0.5)
	testing.expect(t, node.raw != nil, "typed setters should keep the owned node valid")
}

@(test)
test_action_request_borrow_and_copy_preserves_text_after_source_changes :: proc(t: ^testing.T) {
	text_bytes := [12]u8{'s', 'e', 't', ' ', 'v', 'a', 'l', 'u', 'e', 0, 0, 0}
	text_cstring := cast(cstring)rawptr(&text_bytes[0])
	payload := Action_Data_ABI{tag = 1}
	payload.value[0] = u64(uintptr(rawptr(text_cstring)))
	abi_request := Action_Request_ABI{
		action = u8(ACTION_SET_VALUE),
		target_node = u64(Node_ID(42)),
		data = Optional_Action_Data_ABI{has_value = true, value = payload},
	}
	request := Action_Request{raw = rawptr(&abi_request)}

	view, view_ok := action_request_borrow(&request)
	testing.expect(t, view_ok, "borrowed action request should expose the ABI request")
	testing.expect(t, view.action == ACTION_SET_VALUE, "action kind should be preserved")
	testing.expect(t, view.target_node == Node_ID(42), "target node should be preserved")
	testing.expect(t, view.data_tag == ACTION_DATA_VALUE, "text payload tag should be preserved")

	owned, copy_ok := action_request_copy(view, context.allocator)
	testing.expect(t, copy_ok, "copying a borrowed text payload should succeed")
	defer owned_action_request_destroy(&owned)
	text_bytes[0] = 'X'
	testing.expect(t, owned.text_value == "set value", "owned snapshot must not alias the C payload")
}
