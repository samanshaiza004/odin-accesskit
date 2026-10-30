package main

import "core:fmt"
import ak "accesskit:accesskit"

main :: proc() {
	root, root_ok := ak.node_create(ak.ROLE_WINDOW)
	if !root_ok { return }
	defer ak.node_destroy(&root)

	button, button_ok := ak.node_create(ak.ROLE_BUTTON)
	if !button_ok { return }
	defer ak.node_destroy(&button)

	ak.node_push_child(&root, ak.Node_ID(2))
	ak.node_set_label(&button, "Save")
	ak.node_add_action(&button, ak.ACTION_CLICK)
	if !ak.node_supports_action(&button, ak.ACTION_CLICK) { return }

	tree, tree_ok := ak.tree_info_create(ak.Node_ID(1))
	if !tree_ok { return }
	defer ak.tree_info_destroy(&tree)
	ak.tree_info_set_toolkit_name(&tree, "External Odin consumer")

	update, update_ok := ak.tree_update_create(2, ak.Node_ID(1))
	if !update_ok { return }
	defer ak.tree_update_destroy(&update)
	if !ak.tree_update_set_tree_info(&update, &tree) { return }
	if !ak.tree_update_push_node(&update, ak.Node_ID(1), &root) { return }
	if !ak.tree_update_push_node(&update, ak.Node_ID(2), &button) { return }

	fmt.println("AccessKit external consumer built a two-node update.")
}
