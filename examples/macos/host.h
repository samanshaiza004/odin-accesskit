#ifndef ODIN_ACCESSKIT_EXAMPLE_HOST_H
#define ODIN_ACCESSKIT_EXAMPLE_HOST_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// A deliberately small C boundary. No AccessKit declarations or ownership live
// here. All functions except run_worker must be called on the main thread.
enum { EXAMPLE_TICK, EXAMPLE_KEY, EXAMPLE_TEXT, EXAMPLE_FOCUS, EXAMPLE_CLICK };
enum {
    EXAMPLE_TAB = 1, EXAMPLE_RETURN, EXAMPLE_SPACE, EXAMPLE_BACKSPACE,
    EXAMPLE_DELETE, EXAMPLE_LEFT, EXAMPLE_RIGHT, EXAMPLE_HOME, EXAMPLE_END,
    EXAMPLE_SELECT_ALL
};
typedef void (*example_event_callback)(void *userdata, int32_t event,
    const char *text, size_t length, int32_t argument, bool shift);
typedef void (*example_worker_callback)(void *userdata);

void *example_host_create(example_event_callback callback, void *userdata);
void *example_host_window(void *host); // borrowed NSWindow; never release it
void example_host_present(void *host, const char *button, size_t button_length,
    const char *text, size_t text_length, uint64_t focus,
    size_t anchor, size_t caret);
void example_host_run(void *host);
void example_host_focus(void *host);
void example_host_stop(void *host);
void example_host_destroy(void *host); // only AFTER freeing the adapter
bool example_host_is_main_thread(void);
bool example_host_run_worker(example_worker_callback callback, void *userdata);

#endif
