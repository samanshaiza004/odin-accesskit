# C callbacks and threads

Callbacks use `proc "c"`; ordinary Odin procedures use a different calling
convention and implicit context. Establish a context before calling
context-dependent Odin code:

```odin
action :: proc "c" (request, userdata: rawptr) {
    context = runtime.default_context()
    // Snapshot and destroy the C request, then queue the owned snapshot.
}
```

Import `base:runtime` under the `runtime` alias in this example. Use an explicit
allocator that remains valid on the callback thread and until the queued
snapshot is consumed. Do not use a frame/temp allocator across callbacks or
threads. Protect shared queues and allocator use with synchronization.

A Windows action callback may run on a UIA thread. Deliver requests to the
application's event thread through its own queue/wake mechanism. The binding
does not choose a queue, scheduler, SDL event, mutex or application action model.
Native adapter operations follow their platform thread rules; see
[platforms](platforms.md). Callback userdata must outlive the adapter and all
in-flight callback work. Never let an Odin panic unwind through C.

Activation and update-factory callbacks return a newly owned, non-nil update
(normally `tree_update_take`). Build a complete tree for activation, and valid
ordered updates afterward. AccessKit consumes them. Keep application state
consistent while a callback reads it. Action requests are single-owner values;
free them exactly once, even for unsupported actions or shutdown.
