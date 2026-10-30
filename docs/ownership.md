# Ownership

`Node`, `Tree_Info`, `Tree_Update`, platform adapters and queued-event wrappers
contain owning C pointers. **Do not copy owning structs.** Odin does not enforce
move-only types. Use pointer-taking helpers and destroy each untransferred
handle once; destruction clears it. Borrowed raw pointers never extend a lifetime.

`tree_update_push_node` consumes and clears a Node. `tree_update_set_tree_info`
consumes and clears Tree_Info. The pinned header omits the latter's ownership
comment, but the [0.23.1 implementation](https://github.com/AccessKit/accesskit-c/blob/0.23.1/src/common.rs)
reconstitutes a Box and moves its value into the update. The regression reads
that metadata after transfer and destroys the update. `tree_update_take`
transfers an update to an adapter; never free or resubmit that raw pointer.

String and slice setters borrow storage for the duration of the call. AccessKit
copies the data. Getter strings allocated by C require `accesskit_string_free`,
not an Odin allocator. ABI request views expire when the request is freed.

Action callbacks own their request. `action_request_snapshot_and_destroy`
copies supported payloads into an explicit allocator and always frees the C
request, including allocation failure. Destroy the snapshot after use. Queued
platform events must be raised once, which delivers and frees them and clears
the wrapper. Destroy adapters before destroying their native windows.
