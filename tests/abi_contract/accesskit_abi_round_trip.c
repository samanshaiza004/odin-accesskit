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
