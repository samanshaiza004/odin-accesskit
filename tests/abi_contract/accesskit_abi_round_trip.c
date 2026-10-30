/*
 * Small C shim called by Odin tests. This verifies real cross-language
 * aggregate argument and return passing using the pinned AccessKit types.
 */

#include "accesskit.h"

accesskit_rect
accesskit_abi_rect_round_trip(accesskit_rect value)
{
	return value;
}

accesskit_text_selection
accesskit_abi_text_selection_round_trip(accesskit_text_selection value)
{
	return value;
}

/* Construct every tagged payload in C so Odin cannot accidentally validate
 * its own incorrect union encoding against itself. This is borrowed test data. */
accesskit_action_data accesskit_abi_action_data_make(int tag)
{
    accesskit_action_data result = {0};
    static char text[] = "copied text";
    result.tag = (accesskit_action_data_Tag)tag;
    switch (tag) {
    case ACCESSKIT_ACTION_DATA_CUSTOM_ACTION: result.custom_action = -7; break;
    case ACCESSKIT_ACTION_DATA_VALUE: result.value = text; break;
    case ACCESSKIT_ACTION_DATA_NUMERIC_VALUE: result.numeric_value = -6.25; break;
    case ACCESSKIT_ACTION_DATA_SCROLL_UNIT: result.scroll_unit = 1; break;
    case ACCESSKIT_ACTION_DATA_SCROLL_HINT: result.scroll_hint = 1; break;
    case ACCESSKIT_ACTION_DATA_SCROLL_TO_POINT:
        result.scroll_to_point.x = 12.5; result.scroll_to_point.y = -3.25; break;
    case ACCESSKIT_ACTION_DATA_SET_SCROLL_OFFSET:
        result.set_scroll_offset.x = 12.5; result.set_scroll_offset.y = -3.25; break;
    case ACCESSKIT_ACTION_DATA_SET_TEXT_SELECTION:
        result.set_text_selection.anchor.node = 7;
        result.set_text_selection.anchor.character_index = 2;
        result.set_text_selection.focus.node = 9;
        result.set_text_selection.focus.character_index = 4; break;
    }
    return result;
}
