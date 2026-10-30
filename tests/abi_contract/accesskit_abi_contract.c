/*
 * C-header contract for the AccessKit version pinned by tools/bootstrap.sh.
 * Keep this independent of UI toolkits and native window creation.
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "accesskit.h"
#include "enums_generated.h"

#define ABI_ASSERT(name, expression) _Static_assert((expression), #name)

/* Scalar widths mirrored by the standalone Odin binding. */
ABI_ASSERT(accesskit_action_is_u8, sizeof(accesskit_action) == 1);
ABI_ASSERT(accesskit_role_is_u8, sizeof(accesskit_role) == 1);
ABI_ASSERT(accesskit_node_id_is_u64, sizeof(accesskit_node_id) == 8);
ABI_ASSERT(action_data_tag_is_int, sizeof(((accesskit_action_data *)0)->tag) == sizeof(int));

/* Struct layouts mirrored by the standalone accesskit/accesskit.odin binding. */
ABI_ASSERT(rect_size, sizeof(accesskit_rect) == 32);
ABI_ASSERT(rect_alignment, _Alignof(accesskit_rect) == 8);
ABI_ASSERT(rect_x0_offset, offsetof(accesskit_rect, x0) == 0);
ABI_ASSERT(rect_y0_offset, offsetof(accesskit_rect, y0) == 8);
ABI_ASSERT(rect_x1_offset, offsetof(accesskit_rect, x1) == 16);
ABI_ASSERT(rect_y1_offset, offsetof(accesskit_rect, y1) == 24);

ABI_ASSERT(text_position_size, sizeof(accesskit_text_position) == 16);
ABI_ASSERT(text_position_alignment, _Alignof(accesskit_text_position) == 8);
ABI_ASSERT(text_position_node_offset, offsetof(accesskit_text_position, node) == 0);
ABI_ASSERT(text_position_character_index_offset,
           offsetof(accesskit_text_position, character_index) == 8);
ABI_ASSERT(text_selection_size, sizeof(accesskit_text_selection) == 32);
ABI_ASSERT(text_selection_alignment, _Alignof(accesskit_text_selection) == 8);
ABI_ASSERT(text_selection_anchor_offset, offsetof(accesskit_text_selection, anchor) == 0);
ABI_ASSERT(text_selection_focus_offset, offsetof(accesskit_text_selection, focus) == 16);

ABI_ASSERT(action_data_size, sizeof(accesskit_action_data) == 40);
ABI_ASSERT(action_data_alignment, _Alignof(accesskit_action_data) == 8);
ABI_ASSERT(action_data_tag_offset, offsetof(accesskit_action_data, tag) == 0);
ABI_ASSERT(action_data_union_offset, offsetof(accesskit_action_data, value) == 8);
ABI_ASSERT(optional_action_data_size, sizeof(accesskit_opt_action_data) == 48);
ABI_ASSERT(optional_action_data_alignment, _Alignof(accesskit_opt_action_data) == 8);
ABI_ASSERT(optional_action_data_flag_offset, offsetof(accesskit_opt_action_data, has_value) == 0);
ABI_ASSERT(optional_action_data_value_offset, offsetof(accesskit_opt_action_data, value) == 8);
ABI_ASSERT(optional_rect_size, sizeof(accesskit_opt_rect) == 40);
ABI_ASSERT(optional_rect_alignment, _Alignof(accesskit_opt_rect) == 8);
ABI_ASSERT(optional_rect_flag_offset, offsetof(accesskit_opt_rect, has_value) == 0);
ABI_ASSERT(optional_rect_value_offset, offsetof(accesskit_opt_rect, value) == 8);
ABI_ASSERT(optional_text_selection_size, sizeof(accesskit_opt_text_selection) == 40);
ABI_ASSERT(optional_text_selection_alignment, _Alignof(accesskit_opt_text_selection) == 8);
ABI_ASSERT(optional_text_selection_flag_offset,
           offsetof(accesskit_opt_text_selection, has_value) == 0);
ABI_ASSERT(optional_text_selection_value_offset,
           offsetof(accesskit_opt_text_selection, value) == 8);

ABI_ASSERT(tree_id_size, sizeof(accesskit_tree_id) == 16);
ABI_ASSERT(action_request_size, sizeof(accesskit_action_request) == 80);
ABI_ASSERT(action_request_alignment, _Alignof(accesskit_action_request) == 8);
ABI_ASSERT(action_request_action_offset, offsetof(accesskit_action_request, action) == 0);
ABI_ASSERT(action_request_tree_offset, offsetof(accesskit_action_request, target_tree) == 1);
ABI_ASSERT(action_request_node_offset, offsetof(accesskit_action_request, target_node) == 24);
ABI_ASSERT(action_request_data_offset, offsetof(accesskit_action_request, data) == 32);

/* Actions covered by this binding. */
ABI_ASSERT(action_click_value, ACCESSKIT_ACTION_CLICK == 0);
ABI_ASSERT(action_focus_value, ACCESSKIT_ACTION_FOCUS == 1);
ABI_ASSERT(action_blur_value, ACCESSKIT_ACTION_BLUR == 2);
ABI_ASSERT(action_collapse_value, ACCESSKIT_ACTION_COLLAPSE == 3);
ABI_ASSERT(action_expand_value, ACCESSKIT_ACTION_EXPAND == 4);
ABI_ASSERT(action_custom_action_value, ACCESSKIT_ACTION_CUSTOM_ACTION == 5);
ABI_ASSERT(action_decrement_value, ACCESSKIT_ACTION_DECREMENT == 6);
ABI_ASSERT(action_increment_value, ACCESSKIT_ACTION_INCREMENT == 7);
ABI_ASSERT(action_hide_tooltip_value, ACCESSKIT_ACTION_HIDE_TOOLTIP == 8);
ABI_ASSERT(action_show_tooltip_value, ACCESSKIT_ACTION_SHOW_TOOLTIP == 9);
ABI_ASSERT(action_replace_selected_text_value, ACCESSKIT_ACTION_REPLACE_SELECTED_TEXT == 10);
ABI_ASSERT(action_scroll_down_value, ACCESSKIT_ACTION_SCROLL_DOWN == 11);
ABI_ASSERT(action_scroll_left_value, ACCESSKIT_ACTION_SCROLL_LEFT == 12);
ABI_ASSERT(action_scroll_right_value, ACCESSKIT_ACTION_SCROLL_RIGHT == 13);
ABI_ASSERT(action_scroll_up_value, ACCESSKIT_ACTION_SCROLL_UP == 14);
ABI_ASSERT(action_scroll_into_view_value, ACCESSKIT_ACTION_SCROLL_INTO_VIEW == 15);
ABI_ASSERT(action_scroll_to_point_value, ACCESSKIT_ACTION_SCROLL_TO_POINT == 16);
ABI_ASSERT(action_set_scroll_offset_value, ACCESSKIT_ACTION_SET_SCROLL_OFFSET == 17);
ABI_ASSERT(action_set_text_selection_value, ACCESSKIT_ACTION_SET_TEXT_SELECTION == 18);
ABI_ASSERT(action_set_sequential_focus_navigation_starting_point_value,
           ACCESSKIT_ACTION_SET_SEQUENTIAL_FOCUS_NAVIGATION_STARTING_POINT == 19);
ABI_ASSERT(action_set_value_value, ACCESSKIT_ACTION_SET_VALUE == 20);

/* Action-data tags covered by this binding. */
ABI_ASSERT(action_data_value_tag, ACCESSKIT_ACTION_DATA_VALUE == 1);
ABI_ASSERT(action_data_numeric_value_tag, ACCESSKIT_ACTION_DATA_NUMERIC_VALUE == 2);
ABI_ASSERT(action_data_custom_action_tag, ACCESSKIT_ACTION_DATA_CUSTOM_ACTION == 0);
ABI_ASSERT(action_data_scroll_unit_tag, ACCESSKIT_ACTION_DATA_SCROLL_UNIT == 3);
ABI_ASSERT(action_data_scroll_hint_tag, ACCESSKIT_ACTION_DATA_SCROLL_HINT == 4);
ABI_ASSERT(action_data_scroll_to_point_tag, ACCESSKIT_ACTION_DATA_SCROLL_TO_POINT == 5);
ABI_ASSERT(action_data_set_scroll_offset_tag, ACCESSKIT_ACTION_DATA_SET_SCROLL_OFFSET == 6);
ABI_ASSERT(action_data_set_text_selection_tag,
           ACCESSKIT_ACTION_DATA_SET_TEXT_SELECTION == 7);

/* Every named role exposed by the Odin AccessKit binding. */
ABI_ASSERT(role_unknown_value, ACCESSKIT_ROLE_UNKNOWN == 0);
ABI_ASSERT(role_text_run_value, ACCESSKIT_ROLE_TEXT_RUN == 1);
ABI_ASSERT(role_label_value, ACCESSKIT_ROLE_LABEL == 3);
ABI_ASSERT(role_image_value, ACCESSKIT_ROLE_IMAGE == 4);
ABI_ASSERT(role_link_value, ACCESSKIT_ROLE_LINK == 5);
ABI_ASSERT(role_list_item_value, ACCESSKIT_ROLE_LIST_ITEM == 7);
ABI_ASSERT(role_tree_item_value, ACCESSKIT_ROLE_TREE_ITEM == 9);
ABI_ASSERT(role_list_box_option_value, ACCESSKIT_ROLE_LIST_BOX_OPTION == 10);
ABI_ASSERT(role_menu_item_value, ACCESSKIT_ROLE_MENU_ITEM == 11);
ABI_ASSERT(role_paragraph_value, ACCESSKIT_ROLE_PARAGRAPH == 13);
ABI_ASSERT(role_generic_container_value, ACCESSKIT_ROLE_GENERIC_CONTAINER == 14);
ABI_ASSERT(role_check_box_value, ACCESSKIT_ROLE_CHECK_BOX == 15);
ABI_ASSERT(role_radio_button_value, ACCESSKIT_ROLE_RADIO_BUTTON == 16);
ABI_ASSERT(role_text_input_value, ACCESSKIT_ROLE_TEXT_INPUT == 17);
ABI_ASSERT(role_button_value, ACCESSKIT_ROLE_BUTTON == 18);
ABI_ASSERT(role_list_value, ACCESSKIT_ROLE_LIST == 24);
ABI_ASSERT(role_menu_value, ACCESSKIT_ROLE_MENU == 30);
ABI_ASSERT(role_multiline_text_input_value, ACCESSKIT_ROLE_MULTILINE_TEXT_INPUT == 31);
ABI_ASSERT(role_search_input_value, ACCESSKIT_ROLE_SEARCH_INPUT == 32);
ABI_ASSERT(role_alert_value, ACCESSKIT_ROLE_ALERT == 44);
ABI_ASSERT(role_combo_box_value, ACCESSKIT_ROLE_COMBO_BOX == 56);
ABI_ASSERT(role_dialog_value, ACCESSKIT_ROLE_DIALOG == 66);
ABI_ASSERT(role_group_value, ACCESSKIT_ROLE_GROUP == 78);
ABI_ASSERT(role_list_box_value, ACCESSKIT_ROLE_LIST_BOX == 87);
ABI_ASSERT(role_scroll_view_value, ACCESSKIT_ROLE_SCROLL_VIEW == 108);
ABI_ASSERT(role_slider_value, ACCESSKIT_ROLE_SLIDER == 113);
ABI_ASSERT(role_status_value, ACCESSKIT_ROLE_STATUS == 116);
ABI_ASSERT(role_tab_value, ACCESSKIT_ROLE_TAB == 120);
ABI_ASSERT(role_tab_list_value, ACCESSKIT_ROLE_TAB_LIST == 121);
ABI_ASSERT(role_tab_panel_value, ACCESSKIT_ROLE_TAB_PANEL == 122);
ABI_ASSERT(role_tooltip_value, ACCESSKIT_ROLE_TOOLTIP == 128);
ABI_ASSERT(role_tree_value, ACCESSKIT_ROLE_TREE == 129);
ABI_ASSERT(role_window_value, ACCESSKIT_ROLE_WINDOW == 133);

/* State enums passed to node setters. */
ABI_ASSERT(aria_current_false_value, ACCESSKIT_ARIA_CURRENT_FALSE == 0);
ABI_ASSERT(aria_current_true_value, ACCESSKIT_ARIA_CURRENT_TRUE == 1);
ABI_ASSERT(aria_current_page_value, ACCESSKIT_ARIA_CURRENT_PAGE == 2);
ABI_ASSERT(aria_current_step_value, ACCESSKIT_ARIA_CURRENT_STEP == 3);
ABI_ASSERT(aria_current_location_value, ACCESSKIT_ARIA_CURRENT_LOCATION == 4);
ABI_ASSERT(aria_current_date_value, ACCESSKIT_ARIA_CURRENT_DATE == 5);
ABI_ASSERT(aria_current_time_value, ACCESSKIT_ARIA_CURRENT_TIME == 6);
ABI_ASSERT(invalid_true_value, ACCESSKIT_INVALID_TRUE == 0);
ABI_ASSERT(invalid_grammar_value, ACCESSKIT_INVALID_GRAMMAR == 1);
ABI_ASSERT(invalid_spelling_value, ACCESSKIT_INVALID_SPELLING == 2);
ABI_ASSERT(live_off_value, ACCESSKIT_LIVE_OFF == 0);
ABI_ASSERT(live_polite_value, ACCESSKIT_LIVE_POLITE == 1);
ABI_ASSERT(live_assertive_value, ACCESSKIT_LIVE_ASSERTIVE == 2);
ABI_ASSERT(toggled_false_value, ACCESSKIT_TOGGLED_FALSE == 0);
ABI_ASSERT(toggled_true_value, ACCESSKIT_TOGGLED_TRUE == 1);
ABI_ASSERT(toggled_mixed_value, ACCESSKIT_TOGGLED_MIXED == 2);

/*
 * Exercise the header's struct-by-value calling convention without linking an
 * AccessKit adapter or opening a native window. This is a C-side round trip;
 * the static assertions above are the Odin-mirror layout contract.
 */
static accesskit_rect
rect_round_trip(accesskit_rect value)
{
    return value;
}

static accesskit_text_selection
text_selection_round_trip(accesskit_text_selection value)
{
    return value;
}

int
main(void)
{
    accesskit_rect expected_rect;
    expected_rect.x0 = 1.25;
    expected_rect.y0 = -2.5;
    expected_rect.x1 = 640.0;
    expected_rect.y1 = 480.5;

    accesskit_rect actual_rect = rect_round_trip(expected_rect);
    if (actual_rect.x0 != expected_rect.x0 ||
        actual_rect.y0 != expected_rect.y0 ||
        actual_rect.x1 != expected_rect.x1 ||
        actual_rect.y1 != expected_rect.y1) {
        fputs("AccessKit ABI probe: accesskit_rect by-value round trip failed\n", stderr);
        return 1;
    }

    accesskit_text_selection expected_selection;
    expected_selection.anchor.node = UINT64_C(0x0102030405060708);
    expected_selection.anchor.character_index = (size_t)17;
    expected_selection.focus.node = UINT64_C(0x1112131415161718);
    expected_selection.focus.character_index = (size_t)29;

    accesskit_text_selection actual_selection =
        text_selection_round_trip(expected_selection);
    if (actual_selection.anchor.node != expected_selection.anchor.node ||
        actual_selection.anchor.character_index != expected_selection.anchor.character_index ||
        actual_selection.focus.node != expected_selection.focus.node ||
        actual_selection.focus.character_index != expected_selection.focus.character_index) {
        fputs("AccessKit ABI probe: accesskit_text_selection by-value round trip failed\n", stderr);
        return 1;
    }

    puts("AccessKit 0.23.1 C-header ABI contract: PASS");
    return 0;
}
