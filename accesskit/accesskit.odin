package accesskit

import "core:c"
import "core:mem"
import "core:strings"

// This package is a small Odin binding over the common AccessKit C API.
// It deliberately contains no Alicorn semantic model or native-window code.

when ODIN_OS == .Windows {
	foreign import accesskit "system:accesskit.lib"
} else {
	foreign import accesskit "system:accesskit"
}

foreign accesskit {
	accesskit_node_new :: proc "c" (role: u8) -> rawptr ---
	accesskit_node_free :: proc "c" (node: rawptr) ---
	accesskit_node_push_child :: proc "c" (node: rawptr, child: u64) ---
	accesskit_node_add_action :: proc "c" (node: rawptr, action: u8) ---
	accesskit_node_supports_action :: proc "c" (node: rawptr, action: u8) -> bool ---
	accesskit_node_set_label_with_length :: proc "c" (node, value: rawptr, length: uint) ---
	accesskit_node_label :: proc "c" (node: rawptr) -> cstring ---
	accesskit_node_set_description_with_length :: proc "c" (node, value: rawptr, length: uint) ---
	accesskit_node_set_value_with_length :: proc "c" (node, value: rawptr, length: uint) ---
	accesskit_node_set_bounds :: proc "c" (node: rawptr, bounds: Rect) ---
	accesskit_node_set_character_lengths :: proc "c" (node: rawptr, length: uint, values: rawptr) ---
	accesskit_node_set_text_selection :: proc "c" (node: rawptr, value: Text_Selection) ---
	accesskit_node_set_live :: proc "c" (node: rawptr, value: u8) ---
	accesskit_node_set_live_atomic :: proc "c" (node: rawptr) ---
	accesskit_node_set_disabled :: proc "c" (node: rawptr) ---
	accesskit_node_clear_disabled :: proc "c" (node: rawptr) ---
	accesskit_node_set_required :: proc "c" (node: rawptr) ---
	accesskit_node_clear_required :: proc "c" (node: rawptr) ---
	accesskit_node_set_read_only :: proc "c" (node: rawptr) ---
	accesskit_node_clear_read_only :: proc "c" (node: rawptr) ---
	accesskit_node_set_busy :: proc "c" (node: rawptr) ---
	accesskit_node_clear_busy :: proc "c" (node: rawptr) ---
	accesskit_node_set_aria_current :: proc "c" (node: rawptr, value: u8) ---
	accesskit_node_set_toggled :: proc "c" (node: rawptr, value: u8) ---
	accesskit_node_set_invalid :: proc "c" (node: rawptr, value: u8) ---
	accesskit_node_set_size_of_set :: proc "c" (node: rawptr, value: uint) ---
	accesskit_node_set_position_in_set :: proc "c" (node: rawptr, value: uint) ---
	accesskit_node_set_numeric_value :: proc "c" (node: rawptr, value: f64) ---
	accesskit_node_set_min_numeric_value :: proc "c" (node: rawptr, value: f64) ---
	accesskit_node_set_max_numeric_value :: proc "c" (node: rawptr, value: f64) ---
	accesskit_node_set_numeric_value_step :: proc "c" (node: rawptr, value: f64) ---
	accesskit_node_set_numeric_value_jump :: proc "c" (node: rawptr, value: f64) ---
	accesskit_node_set_selected :: proc "c" (node: rawptr, selected: bool) ---
	accesskit_node_set_expanded :: proc "c" (node: rawptr, expanded: bool) ---
	accesskit_string_free :: proc "c" (value: cstring) ---
	accesskit_tree_info_new :: proc "c" (root: u64) -> rawptr ---
	accesskit_tree_info_free :: proc "c" (tree: rawptr) ---
	accesskit_tree_info_set_toolkit_name_with_length :: proc "c" (tree, value: rawptr, length: uint) ---
	accesskit_tree_info_set_toolkit_version_with_length :: proc "c" (tree, value: rawptr, length: uint) ---
	accesskit_tree_update_with_capacity_and_focus :: proc "c" (capacity: uint, focus: u64) -> rawptr ---
	accesskit_tree_update_free :: proc "c" (update: rawptr) ---
	accesskit_tree_update_push_node :: proc "c" (update: rawptr, id: u64, node: rawptr) ---
	accesskit_tree_update_set_tree_info :: proc "c" (update, tree: rawptr) ---
	accesskit_tree_update_set_focus :: proc "c" (update: rawptr, focus: u64) ---
	accesskit_action_request_free :: proc "c" (request: rawptr) ---
}

when ODIN_OS == .Windows {
	foreign accesskit {
		accesskit_windows_subclassing_adapter_new :: proc "c" (
			hwnd: rawptr,
			activation_handler: Activation_Handler,
			activation_userdata: rawptr,
			action_handler: Action_Handler,
			action_userdata: rawptr,
		) -> rawptr ---
		accesskit_windows_subclassing_adapter_free :: proc "c" (adapter: rawptr) ---
		accesskit_windows_subclassing_adapter_update_if_active :: proc "c" (
			adapter: rawptr,
			factory: Update_Factory,
			factory_userdata: rawptr,
		) -> rawptr ---
		accesskit_windows_subclassing_adapter_update_window_focus_state :: proc "c" (
			adapter: rawptr,
			focused: bool,
		) -> rawptr ---
		accesskit_windows_queued_events_raise :: proc "c" (events: rawptr) ---
	}
}

when ODIN_OS == .Darwin {
	foreign accesskit {
		accesskit_macos_subclassing_adapter_for_window :: proc "c" (
			window: rawptr,
			activation_handler: Activation_Handler,
			activation_userdata: rawptr,
			action_handler: Action_Handler,
			action_userdata: rawptr,
		) -> rawptr ---
		accesskit_macos_subclassing_adapter_free :: proc "c" (adapter: rawptr) ---
		accesskit_macos_subclassing_adapter_update_if_active :: proc "c" (
			adapter: rawptr,
			factory: Update_Factory,
			factory_userdata: rawptr,
		) -> rawptr ---
		accesskit_macos_subclassing_adapter_update_view_focus_state :: proc "c" (
			adapter: rawptr,
			focused: bool,
		) -> rawptr ---
		accesskit_macos_queued_events_raise :: proc "c" (events: rawptr) ---
		accesskit_macos_add_focus_forwarder_to_window_class :: proc "c" (class_name: cstring) ---
	}
}

// AccessKit calls this to obtain a new owned tree update when its platform
// adapter is active. The callback must return a non-nil C Tree_Update pointer.
Update_Factory :: proc "c" (userdata: rawptr) -> rawptr

// AccessKit transfers each action request to this callback. The callback must
// wrap and destroy it, or call action_request_snapshot_and_destroy.
Action_Handler :: proc "c" (request: rawptr, userdata: rawptr)

// AccessKit activation handlers return a newly allocated C Tree_Update.
Activation_Handler :: proc "c" (userdata: rawptr) -> rawptr

@(private)
empty_string_byte: u8 = 0

// Role is the AccessKit 0.23.1 role byte. The named constants below cover
// common controls; converting another pinned-header value to Role keeps the
// wrapper forward-compatible without introducing a second role taxonomy.
Role :: distinct u8

ROLE_UNKNOWN :: Role(0)
ROLE_TEXT_RUN :: Role(1)
ROLE_LABEL :: Role(3)
ROLE_IMAGE :: Role(4)
ROLE_LINK :: Role(5)
ROLE_LIST_ITEM :: Role(7)
ROLE_TREE_ITEM :: Role(9)
ROLE_MENU_ITEM :: Role(11)
ROLE_PARAGRAPH :: Role(13)
ROLE_GENERIC_CONTAINER :: Role(14)
ROLE_CHECK_BOX :: Role(15)
ROLE_RADIO_BUTTON :: Role(16)
ROLE_TEXT_INPUT :: Role(17)
ROLE_BUTTON :: Role(18)
ROLE_LIST :: Role(24)
ROLE_MENU :: Role(30)
ROLE_MULTILINE_TEXT_INPUT :: Role(31)
ROLE_SEARCH_INPUT :: Role(32)
ROLE_ALERT :: Role(44)
ROLE_COMBO_BOX :: Role(56)
ROLE_DIALOG :: Role(66)
ROLE_GROUP :: Role(78)
ROLE_LIST_BOX :: Role(87)
ROLE_LIST_BOX_OPTION :: Role(10)
ROLE_SCROLL_VIEW :: Role(108)
ROLE_SLIDER :: Role(113)
ROLE_STATUS :: Role(116)
ROLE_TAB :: Role(120)
ROLE_TAB_LIST :: Role(121)
ROLE_TAB_PANEL :: Role(122)
ROLE_TOOLTIP :: Role(128)
ROLE_TREE :: Role(129)
ROLE_WINDOW :: Role(133)

// Action is an AccessKit 0.23.1 action byte.
Action :: distinct u8

ACTION_CLICK :: Action(0)
ACTION_FOCUS :: Action(1)
ACTION_BLUR :: Action(2)
ACTION_COLLAPSE :: Action(3)
ACTION_EXPAND :: Action(4)
ACTION_CUSTOM_ACTION :: Action(5)
ACTION_DECREMENT :: Action(6)
ACTION_INCREMENT :: Action(7)
ACTION_HIDE_TOOLTIP :: Action(8)
ACTION_SHOW_TOOLTIP :: Action(9)
ACTION_REPLACE_SELECTED_TEXT :: Action(10)
ACTION_SCROLL_DOWN :: Action(11)
ACTION_SCROLL_LEFT :: Action(12)
ACTION_SCROLL_RIGHT :: Action(13)
ACTION_SCROLL_UP :: Action(14)
ACTION_SCROLL_INTO_VIEW :: Action(15)
ACTION_SCROLL_TO_POINT :: Action(16)
ACTION_SET_SCROLL_OFFSET :: Action(17)
ACTION_SET_TEXT_SELECTION :: Action(18)
ACTION_SET_SEQUENTIAL_FOCUS_NAVIGATION_STARTING_POINT :: Action(19)
ACTION_SET_VALUE :: Action(20)

// AccessKit 0.23.1 enum values used by semantic node setters.
Live :: distinct u8
LIVE_OFF :: Live(0)
LIVE_POLITE :: Live(1)
LIVE_ASSERTIVE :: Live(2)

Toggled :: distinct u8
TOGGLED_FALSE :: Toggled(0)
TOGGLED_TRUE :: Toggled(1)
TOGGLED_MIXED :: Toggled(2)

Invalid :: distinct u8
INVALID_TRUE :: Invalid(0)
INVALID_GRAMMAR :: Invalid(1)
INVALID_SPELLING :: Invalid(2)

Aria_Current :: distinct u8
ARIA_CURRENT_FALSE :: Aria_Current(0)
ARIA_CURRENT_TRUE :: Aria_Current(1)
ARIA_CURRENT_PAGE :: Aria_Current(2)
ARIA_CURRENT_STEP :: Aria_Current(3)
ARIA_CURRENT_LOCATION :: Aria_Current(4)
ARIA_CURRENT_DATE :: Aria_Current(5)
ARIA_CURRENT_TIME :: Aria_Current(6)

#assert(size_of(Live) == 1)
#assert(size_of(Toggled) == 1)
#assert(size_of(Invalid) == 1)
#assert(size_of(Aria_Current) == 1)

// Node_ID is an AccessKit identity, not a pointer or array index.
Node_ID :: distinct u64

// Action_Data_Tag is an AccessKit 0.23.1 C enum, whose ABI type is int.
Action_Data_Tag :: distinct c.int

ACTION_DATA_CUSTOM_ACTION :: Action_Data_Tag(0)
ACTION_DATA_VALUE :: Action_Data_Tag(1)
ACTION_DATA_NUMERIC_VALUE :: Action_Data_Tag(2)
ACTION_DATA_SCROLL_UNIT :: Action_Data_Tag(3)
ACTION_DATA_SCROLL_HINT :: Action_Data_Tag(4)
ACTION_DATA_SCROLL_TO_POINT :: Action_Data_Tag(5)
ACTION_DATA_SET_SCROLL_OFFSET :: Action_Data_Tag(6)
ACTION_DATA_SET_TEXT_SELECTION :: Action_Data_Tag(7)

// These guards pin the named Odin identifiers to AccessKit C 0.23.1. The
// companion C-header probe independently checks the same numeric contract.
#assert(u8(ROLE_UNKNOWN) == 0)
#assert(u8(ROLE_TEXT_RUN) == 1)
#assert(u8(ROLE_LABEL) == 3)
#assert(u8(ROLE_IMAGE) == 4)
#assert(u8(ROLE_LINK) == 5)
#assert(u8(ROLE_LIST_ITEM) == 7)
#assert(u8(ROLE_TREE_ITEM) == 9)
#assert(u8(ROLE_LIST_BOX_OPTION) == 10)
#assert(u8(ROLE_MENU_ITEM) == 11)
#assert(u8(ROLE_PARAGRAPH) == 13)
#assert(u8(ROLE_GENERIC_CONTAINER) == 14)
#assert(u8(ROLE_CHECK_BOX) == 15)
#assert(u8(ROLE_RADIO_BUTTON) == 16)
#assert(u8(ROLE_TEXT_INPUT) == 17)
#assert(u8(ROLE_BUTTON) == 18)
#assert(u8(ROLE_LIST) == 24)
#assert(u8(ROLE_MENU) == 30)
#assert(u8(ROLE_MULTILINE_TEXT_INPUT) == 31)
#assert(u8(ROLE_SEARCH_INPUT) == 32)
#assert(u8(ROLE_ALERT) == 44)
#assert(u8(ROLE_COMBO_BOX) == 56)
#assert(u8(ROLE_DIALOG) == 66)
#assert(u8(ROLE_GROUP) == 78)
#assert(u8(ROLE_LIST_BOX) == 87)
#assert(u8(ROLE_SCROLL_VIEW) == 108)
#assert(u8(ROLE_SLIDER) == 113)
#assert(u8(ROLE_STATUS) == 116)
#assert(u8(ROLE_TAB) == 120)
#assert(u8(ROLE_TAB_LIST) == 121)
#assert(u8(ROLE_TAB_PANEL) == 122)
#assert(u8(ROLE_TOOLTIP) == 128)
#assert(u8(ROLE_TREE) == 129)
#assert(u8(ROLE_WINDOW) == 133)
#assert(u8(ACTION_CLICK) == 0)
#assert(u8(ACTION_FOCUS) == 1)
#assert(u8(ACTION_BLUR) == 2)
#assert(u8(ACTION_COLLAPSE) == 3)
#assert(u8(ACTION_EXPAND) == 4)
#assert(u8(ACTION_CUSTOM_ACTION) == 5)
#assert(u8(ACTION_DECREMENT) == 6)
#assert(u8(ACTION_INCREMENT) == 7)
#assert(u8(ACTION_HIDE_TOOLTIP) == 8)
#assert(u8(ACTION_SHOW_TOOLTIP) == 9)
#assert(u8(ACTION_REPLACE_SELECTED_TEXT) == 10)
#assert(u8(ACTION_SCROLL_DOWN) == 11)
#assert(u8(ACTION_SCROLL_LEFT) == 12)
#assert(u8(ACTION_SCROLL_RIGHT) == 13)
#assert(u8(ACTION_SCROLL_UP) == 14)
#assert(u8(ACTION_SCROLL_INTO_VIEW) == 15)
#assert(u8(ACTION_SCROLL_TO_POINT) == 16)
#assert(u8(ACTION_SET_SCROLL_OFFSET) == 17)
#assert(u8(ACTION_SET_TEXT_SELECTION) == 18)
#assert(u8(ACTION_SET_SEQUENTIAL_FOCUS_NAVIGATION_STARTING_POINT) == 19)
#assert(u8(ACTION_SET_VALUE) == 20)
#assert(c.int(ACTION_DATA_CUSTOM_ACTION) == 0)
#assert(c.int(ACTION_DATA_VALUE) == 1)
#assert(c.int(ACTION_DATA_NUMERIC_VALUE) == 2)
#assert(c.int(ACTION_DATA_SCROLL_UNIT) == 3)
#assert(c.int(ACTION_DATA_SCROLL_HINT) == 4)
#assert(c.int(ACTION_DATA_SCROLL_TO_POINT) == 5)
#assert(c.int(ACTION_DATA_SET_SCROLL_OFFSET) == 6)
#assert(c.int(ACTION_DATA_SET_TEXT_SELECTION) == 7)

// Action_Data_ABI mirrors the pinned C action payload: a C int tag followed by
// the 32-byte union. Most callers should use Borrowed_Action_Request instead.
Action_Data_ABI :: struct {
	tag: c.int,
	padding: [4]u8,
	value: [4]u64,
}

Optional_Action_Data_ABI :: struct {
	has_value: bool,
	padding: [7]u8,
	value: Action_Data_ABI,
}

// Text_Position and Text_Selection use UTF-8 character indices per AccessKit.
Text_Position :: struct {
	node: u64,
	character_index: uint,
}

Text_Selection :: struct {
	anchor: Text_Position,
	focus: Text_Position,
}

// Action_Request_ABI mirrors accesskit_action_request from AccessKit 0.23.1.
Action_Request_ABI :: struct {
	action: u8,
	target_tree: [16]u8,
	target_node: u64,
	data: Optional_Action_Data_ABI,
}

#assert(offset_of(Action_Request_ABI, action) == 0)
#assert(offset_of(Action_Request_ABI, target_tree) == 1)
#assert(offset_of(Action_Request_ABI, target_node) == 24)
#assert(offset_of(Action_Request_ABI, data) == 32)
#assert(offset_of(Action_Data_ABI, value) == 8)
#assert(size_of(Action_Data_ABI) == 40)
#assert(align_of(Action_Data_ABI) == 8)
#assert(size_of(Optional_Action_Data_ABI) == 48)
#assert(size_of(Action_Request_ABI) == 80)
#assert(size_of(Text_Position) == 16)
#assert(size_of(Text_Selection) == 32)

// Action_Request owns a C request transferred by AccessKit. Do not copy it.
Action_Request :: struct {
	raw: rawptr,
}

// Borrowed_Action_Request views the request payload without allocating.
// text_value is borrowed from the C request and is valid only until its owner
// is destroyed. Use action_request_snapshot_and_destroy to retain it safely.
Borrowed_Action_Request :: struct {
	action: Action,
	target_tree: [16]u8,
	target_node: Node_ID,
	has_data: bool,
	data_tag: Action_Data_Tag,
	payload: Action_Data_ABI,
	custom_action: i32,
	text_value: cstring,
	numeric_value: f64,
}

// Owned_Action_Request is a stable copy of the callback data. Its text_value
// is allocated with allocator and released by owned_action_request_destroy.
Owned_Action_Request :: struct {
	action: Action,
	target_tree: [16]u8,
	target_node: Node_ID,
	has_data: bool,
	data_tag: Action_Data_Tag,
	payload: Action_Data_ABI,
	custom_action: i32,
	text_value: string,
	numeric_value: f64,
	allocator: mem.Allocator,
}

// Rect uses AccessKit's coordinate convention: x0/y0 are the top-left edge,
// and x1/y1 are the bottom-right edge in a y-down coordinate space.
Rect :: struct {
	x0, y0, x1, y1: f64,
}

// action_request_take adopts a request transferred to an Action_Handler.
action_request_take :: proc(raw_request: rawptr) -> Action_Request {
	return Action_Request{raw = raw_request}
}

action_request_destroy :: proc(request: ^Action_Request) {
	if request == nil || request.raw == nil { return }
	accesskit_action_request_free(request.raw)
	request.raw = nil
}

action_request_borrow :: proc(request: ^Action_Request) -> (view: Borrowed_Action_Request, ok: bool) {
	if request == nil || request.raw == nil { return }
	c_request := cast(^Action_Request_ABI)request.raw
	view.action = Action(c_request.action)
	view.target_tree = c_request.target_tree
	view.target_node = Node_ID(c_request.target_node)
	view.has_data = c_request.data.has_value
	if !view.has_data { return view, true }

	view.data_tag = Action_Data_Tag(c_request.data.value.tag)
	view.payload = c_request.data.value
	switch view.data_tag {
	case ACTION_DATA_CUSTOM_ACTION:
		view.custom_action = cast(i32)c_request.data.value.value[0]
	case ACTION_DATA_VALUE:
		view.text_value = cast(cstring)rawptr(uintptr(c_request.data.value.value[0]))
	case ACTION_DATA_NUMERIC_VALUE:
		view.numeric_value = cast(f64)c_request.data.value.value[0]
	case:
		// Other pinned tags remain observable via data_tag. Their payloads are
		// intentionally not reinterpreted by this small common wrapper.
	}
	return view, true
}

// action_request_copy creates an independently owned snapshot of the borrowed
// request. Its text payload is copied with allocator and may outlive the C
// request. Destroy the result with owned_action_request_destroy.
action_request_copy :: proc(
	view: Borrowed_Action_Request,
	allocator: mem.Allocator = context.allocator,
) -> (owned: Owned_Action_Request, ok: bool) {
	owned = Owned_Action_Request{
		action = view.action,
		target_tree = view.target_tree,
		target_node = view.target_node,
		has_data = view.has_data,
		data_tag = view.data_tag,
		payload = view.payload,
		custom_action = view.custom_action,
		numeric_value = view.numeric_value,
		allocator = allocator,
	}
	if view.has_data && view.data_tag == ACTION_DATA_VALUE && view.text_value != nil {
		text_copy, err := strings.clone_from_cstring(view.text_value, allocator)
		if err != nil { return owned, false }
		owned.text_value = text_copy
		// Do not preserve a borrowed pointer inside the owned snapshot. The
		// safe text copy is in text_value; other payload bytes remain intact.
		owned.payload.value[0] = 0
	}
	return owned, true
}

// action_request_snapshot_and_destroy copies any C-owned text before freeing
// the transferred request. It destroys the request even if allocation fails.
action_request_snapshot_and_destroy :: proc(
	request: ^Action_Request,
	allocator: mem.Allocator = context.allocator,
) -> (owned: Owned_Action_Request, ok: bool) {
	owned.allocator = allocator
	view, view_ok := action_request_borrow(request)
	if !view_ok { return owned, false }
	defer action_request_destroy(request)
	return action_request_copy(view, allocator)
}

owned_action_request_destroy :: proc(request: ^Owned_Action_Request) {
	if request == nil { return }
	if request.text_value != "" { delete(request.text_value, request.allocator) }
	request^ = {}
}

when ODIN_OS == .Windows {
	// Windows_Subclassing_Adapter owns AccessKit's HWND subclass. Create it on
	// the window thread before the HWND becomes visible or receives focus.
	Windows_Subclassing_Adapter :: struct { raw: rawptr }
	Windows_Queued_Events :: struct { raw: rawptr }

	windows_subclassing_adapter_create :: proc(
		hwnd: rawptr,
		activation_handler: Activation_Handler,
		activation_userdata: rawptr,
		action_handler: Action_Handler,
		action_userdata: rawptr,
	) -> (adapter: Windows_Subclassing_Adapter, ok: bool) {
		if hwnd == nil || activation_handler == nil || action_handler == nil {
			return adapter, false
		}
		adapter.raw = accesskit_windows_subclassing_adapter_new(
			hwnd,
			activation_handler,
			activation_userdata,
			action_handler,
			action_userdata,
		)
		return adapter, adapter.raw != nil
	}

	windows_subclassing_adapter_destroy :: proc(adapter: ^Windows_Subclassing_Adapter) {
		if adapter == nil || adapter.raw == nil { return }
		accesskit_windows_subclassing_adapter_free(adapter.raw)
		adapter.raw = nil
	}

	// The returned event queue may be nil when the adapter is inactive. If it
	// is non-nil, raise it exactly once to deliver and free its queued events.
	windows_subclassing_adapter_update_if_active :: proc(
		adapter: ^Windows_Subclassing_Adapter,
		factory: Update_Factory,
		factory_userdata: rawptr,
	) -> Windows_Queued_Events {
		if adapter == nil || adapter.raw == nil || factory == nil { return {} }
		return Windows_Queued_Events{raw = accesskit_windows_subclassing_adapter_update_if_active(
			adapter.raw, factory, factory_userdata,
		)}
	}

	windows_subclassing_adapter_update_focus_state :: proc(
		adapter: ^Windows_Subclassing_Adapter,
		focused: bool,
	) -> Windows_Queued_Events {
		if adapter == nil || adapter.raw == nil { return {} }
		return Windows_Queued_Events{raw = accesskit_windows_subclassing_adapter_update_window_focus_state(
			adapter.raw, focused,
		)}
	}

	windows_queued_events_raise :: proc(events: ^Windows_Queued_Events) {
		if events == nil || events.raw == nil { return }
		accesskit_windows_queued_events_raise(events.raw)
		events.raw = nil
	}
}

when ODIN_OS == .Darwin {
	// MacOS_Subclassing_Adapter owns AccessKit's NSWindow subclassing bridge.
	MacOS_Subclassing_Adapter :: struct { raw: rawptr }
	MacOS_Queued_Events :: struct { raw: rawptr }

	macos_subclassing_adapter_create_for_window :: proc(
		window: rawptr,
		activation_handler: Activation_Handler,
		activation_userdata: rawptr,
		action_handler: Action_Handler,
		action_userdata: rawptr,
	) -> (adapter: MacOS_Subclassing_Adapter, ok: bool) {
		if window == nil || activation_handler == nil || action_handler == nil {
			return adapter, false
		}
		adapter.raw = accesskit_macos_subclassing_adapter_for_window(
			window,
			activation_handler,
			activation_userdata,
			action_handler,
			action_userdata,
		)
		return adapter, adapter.raw != nil
	}

	macos_subclassing_adapter_destroy :: proc(adapter: ^MacOS_Subclassing_Adapter) {
		if adapter == nil || adapter.raw == nil { return }
		accesskit_macos_subclassing_adapter_free(adapter.raw)
		adapter.raw = nil
	}

	macos_subclassing_adapter_update_if_active :: proc(
		adapter: ^MacOS_Subclassing_Adapter,
		factory: Update_Factory,
		factory_userdata: rawptr,
	) -> MacOS_Queued_Events {
		if adapter == nil || adapter.raw == nil || factory == nil { return {} }
		return MacOS_Queued_Events{raw = accesskit_macos_subclassing_adapter_update_if_active(
			adapter.raw, factory, factory_userdata,
		)}
	}

	macos_subclassing_adapter_update_focus_state :: proc(
		adapter: ^MacOS_Subclassing_Adapter,
		focused: bool,
	) -> MacOS_Queued_Events {
		if adapter == nil || adapter.raw == nil { return {} }
		return MacOS_Queued_Events{raw = accesskit_macos_subclassing_adapter_update_view_focus_state(
			adapter.raw, focused,
		)}
	}

	macos_queued_events_raise :: proc(events: ^MacOS_Queued_Events) {
		if events == nil || events.raw == nil { return }
		accesskit_macos_queued_events_raise(events.raw)
		events.raw = nil
	}

	// AccessKit installs a permanent method on this NSWindow subclass. The
	// AccessKit library must stay loaded for the process lifetime; prefer static
	// linking when this helper is used. class_name must be a NUL-terminated name.
	macos_add_focus_forwarder_to_window_class :: proc(class_name: cstring) {
		if class_name == nil { return }
		accesskit_macos_add_focus_forwarder_to_window_class(class_name)
	}
}

// Node owns an AccessKit node until it is pushed into a Tree_Update.
// Do not copy Node values; use node_destroy for any node not transferred.
Node :: struct {
	raw: rawptr,
}

// Tree_Info owns an AccessKit tree-info value until it is set on a
// Tree_Update. Do not copy Tree_Info values.
Tree_Info :: struct {
	raw: rawptr,
}

// Tree_Update owns nodes and tree info transferred into it. Destroy it if it
// is not handed to an AccessKit platform adapter.
Tree_Update :: struct {
	raw: rawptr,
}

node_create :: proc(role: Role) -> (node: Node, ok: bool) {
	node.raw = accesskit_node_new(u8(role))
	return node, node.raw != nil
}

node_destroy :: proc(node: ^Node) {
	if node == nil || node.raw == nil { return }
	accesskit_node_free(node.raw)
	node.raw = nil
}

node_push_child :: proc(node: ^Node, child: Node_ID) {
	if node == nil || node.raw == nil { return }
	accesskit_node_push_child(node.raw, u64(child))
}

node_add_action :: proc(node: ^Node, action: Action) {
	if node == nil || node.raw == nil { return }
	accesskit_node_add_action(node.raw, u8(action))
}

node_supports_action :: proc(node: ^Node, action: Action) -> bool {
	return node != nil && node.raw != nil && accesskit_node_supports_action(node.raw, u8(action))
}

node_set_label :: proc(node: ^Node, value: string) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_label_with_length(node.raw, string_pointer(value), uint(len(value)))
}

node_set_description :: proc(node: ^Node, value: string) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_description_with_length(node.raw, string_pointer(value), uint(len(value)))
}

node_set_value :: proc(node: ^Node, value: string) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_value_with_length(node.raw, string_pointer(value), uint(len(value)))
}

node_set_bounds :: proc(node: ^Node, bounds: Rect) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_bounds(node.raw, bounds)
}

node_set_character_lengths :: proc(node: ^Node, lengths: []u8) {
	if node == nil || node.raw == nil { return }
	values: rawptr
	if len(lengths) > 0 { values = rawptr(raw_data(lengths)) }
	accesskit_node_set_character_lengths(node.raw, uint(len(lengths)), values)
}

node_set_text_selection :: proc(node: ^Node, selection: Text_Selection) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_text_selection(node.raw, selection)
}

node_set_live :: proc(node: ^Node, live: Live) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_live(node.raw, u8(live))
}

node_set_live_atomic :: proc(node: ^Node) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_live_atomic(node.raw)
}

node_set_disabled :: proc(node: ^Node, disabled: bool) {
	if node == nil || node.raw == nil { return }
	if disabled {
		accesskit_node_set_disabled(node.raw)
	} else {
		accesskit_node_clear_disabled(node.raw)
	}
}

node_set_required :: proc(node: ^Node) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_required(node.raw)
}

node_set_read_only :: proc(node: ^Node) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_read_only(node.raw)
}

node_set_invalid :: proc(node: ^Node, value: Invalid) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_invalid(node.raw, u8(value))
}

node_set_busy :: proc(node: ^Node) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_busy(node.raw)
}

node_set_aria_current :: proc(node: ^Node, value: Aria_Current) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_aria_current(node.raw, u8(value))
}

node_set_toggled :: proc(node: ^Node, value: Toggled) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_toggled(node.raw, u8(value))
}

node_set_position_in_set :: proc(node: ^Node, value: uint) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_position_in_set(node.raw, value)
}

node_set_size_of_set :: proc(node: ^Node, value: uint) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_size_of_set(node.raw, value)
}

node_set_numeric_value :: proc(node: ^Node, value: f64) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_numeric_value(node.raw, value)
}

node_set_min_numeric_value :: proc(node: ^Node, value: f64) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_min_numeric_value(node.raw, value)
}

node_set_max_numeric_value :: proc(node: ^Node, value: f64) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_max_numeric_value(node.raw, value)
}

node_set_numeric_value_step :: proc(node: ^Node, value: f64) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_numeric_value_step(node.raw, value)
}

node_set_selected :: proc(node: ^Node, selected: bool) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_selected(node.raw, selected)
}

node_set_expanded :: proc(node: ^Node, expanded: bool) {
	if node == nil || node.raw == nil { return }
	accesskit_node_set_expanded(node.raw, expanded)
}

tree_info_create :: proc(root: Node_ID) -> (tree: Tree_Info, ok: bool) {
	tree.raw = accesskit_tree_info_new(u64(root))
	return tree, tree.raw != nil
}

tree_info_destroy :: proc(tree: ^Tree_Info) {
	if tree == nil || tree.raw == nil { return }
	accesskit_tree_info_free(tree.raw)
	tree.raw = nil
}

tree_info_set_toolkit_name :: proc(tree: ^Tree_Info, value: string) {
	if tree == nil || tree.raw == nil { return }
	accesskit_tree_info_set_toolkit_name_with_length(tree.raw, string_pointer(value), uint(len(value)))
}

tree_info_set_toolkit_version :: proc(tree: ^Tree_Info, value: string) {
	if tree == nil || tree.raw == nil { return }
	accesskit_tree_info_set_toolkit_version_with_length(tree.raw, string_pointer(value), uint(len(value)))
}

tree_update_create :: proc(capacity: uint, focus: Node_ID) -> (update: Tree_Update, ok: bool) {
	update.raw = accesskit_tree_update_with_capacity_and_focus(capacity, u64(focus))
	return update, update.raw != nil
}

tree_update_destroy :: proc(update: ^Tree_Update) {
	if update == nil || update.raw == nil { return }
	accesskit_tree_update_free(update.raw)
	update.raw = nil
}

// tree_update_push_node transfers ownership of node to update. On success the
// caller's handle is cleared, so a later node_destroy is harmless.
tree_update_push_node :: proc(update: ^Tree_Update, id: Node_ID, node: ^Node) -> bool {
	if update == nil || update.raw == nil || node == nil || node.raw == nil { return false }
	accesskit_tree_update_push_node(update.raw, u64(id), node.raw)
	node.raw = nil
	return true
}

// tree_update_set_tree_info transfers ownership of tree to update.
tree_update_set_tree_info :: proc(update: ^Tree_Update, tree: ^Tree_Info) -> bool {
	if update == nil || update.raw == nil || tree == nil || tree.raw == nil { return false }
	accesskit_tree_update_set_tree_info(update.raw, tree.raw)
	tree.raw = nil
	return true
}

tree_update_set_focus :: proc(update: ^Tree_Update, focus: Node_ID) {
	if update == nil || update.raw == nil { return }
	accesskit_tree_update_set_focus(update.raw, u64(focus))
}

// tree_update_take releases the opaque AccessKit update to a native adapter.
// The receiver owns it and must eventually follow that adapter's destruction
// contract. The returned pointer is an AccessKit C API handle, not an Odin
// allocation.
tree_update_take :: proc(update: ^Tree_Update) -> rawptr {
	if update == nil { return nil }
	raw := update.raw
	update.raw = nil
	return raw
}

@(private)
string_pointer :: proc(value: string) -> rawptr {
	// Keep the C slice pointer non-nil even for length zero. Some Rust FFI
	// implementations form a zero-length slice from this pointer.
	if len(value) == 0 { return rawptr(&empty_string_byte) }
	return rawptr(raw_data(value))
}
