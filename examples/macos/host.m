#import <AppKit/AppKit.h>
#include <assert.h>
#include <math.h>
#include <pthread.h>
#include <stdlib.h>
#include "host.h"

@class AKExampleHost;

@interface AKExampleView : NSView
@property(nonatomic, weak) AKExampleHost *host;
@property(nonatomic, copy) NSString *buttonText;
@property(nonatomic, copy) NSString *text;
@property(nonatomic) uint64_t focusedNode;
@property(nonatomic) NSUInteger anchor;
@property(nonatomic) NSUInteger caret;
@end

@interface AKExampleHost : NSObject <NSWindowDelegate, NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) AKExampleView *view;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) example_event_callback callback;
@property(nonatomic) void *userdata;
@property(nonatomic) BOOL stopping;
- (void)emit:(int32_t)event argument:(int32_t)argument shift:(BOOL)shift;
- (void)requestQuit:(id)sender;
@end

// Keep these point coordinates in step with the semantic bounds in main.odin.
static const NSRect buttonRect = {{24, 40}, {260, 44}};
static const NSRect fieldRect = {{24, 140}, {512, 42}};

static void activateApplication(void) {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
    if (@available(macOS 14.0, *)) {
        [NSApp activate];
        return;
    }
#endif
    // Keep the older runtime path usable with recent SDKs and -Werror.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [NSApp activateIgnoringOtherApps:YES];
#pragma clang diagnostic pop
}

// The editor's AccessKit character is one Unicode scalar. NSString uses UTF-16.
static NSUInteger utf16Index(NSString *text, NSUInteger scalarIndex) {
    NSUInteger offset = 0;
    while (scalarIndex-- && offset < text.length) {
        unichar first = [text characterAtIndex:offset++];
        if (first >= 0xD800 && first <= 0xDBFF && offset < text.length) {
            unichar second = [text characterAtIndex:offset];
            if (second >= 0xDC00 && second <= 0xDFFF) ++offset;
        }
    }
    return offset;
}

@implementation AKExampleView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder {
    [self.host emit:EXAMPLE_FOCUS argument:self.window.isKeyWindow shift:NO];
    return YES;
}
- (BOOL)resignFirstResponder {
    [self.host emit:EXAMPLE_FOCUS argument:0 shift:NO];
    return YES;
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor windowBackgroundColor] setFill];
    NSRectFill(self.bounds);
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:16 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor textColor]
    };
    [[NSColor controlColor] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:6 yRadius:6] fill];
    [self.buttonText drawAtPoint:NSMakePoint(36, 51) withAttributes:attributes];
    [@"Message" drawAtPoint:NSMakePoint(24, 112) withAttributes:attributes];
    [[NSColor textBackgroundColor] setFill];
    NSRectFill(fieldRect);
    NSRect activeRect = self.focusedNode == 2 ? buttonRect : fieldRect;
    if (self.window.isKeyWindow && self.window.firstResponder == self) {
        [[NSColor keyboardFocusIndicatorColor] setStroke];
        NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:
            NSInsetRect(activeRect, -2, -2) xRadius:6 yRadius:6];
        outline.lineWidth = 2;
        [outline stroke];
    }
    // Clip the simple one-line editor; long text has no horizontal scrolling.
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(NSInsetRect(fieldRect, 8, 2));
    NSUInteger a = utf16Index(self.text, self.anchor);
    NSUInteger c = utf16Index(self.text, self.caret);
    CGFloat ax = [[self.text substringToIndex:a] sizeWithAttributes:attributes].width;
    CGFloat cx = [[self.text substringToIndex:c] sizeWithAttributes:attributes].width;
    if (self.focusedNode == 3) {
        [[NSColor selectedTextBackgroundColor] setFill];
        NSRectFill(NSMakeRect(36 + MIN(ax, cx), 148, MAX(1, fabs(cx - ax)), 24));
    }
    [self.text drawAtPoint:NSMakePoint(36, 148) withAttributes:attributes];
    [NSGraphicsContext restoreGraphicsState];
    [@"Tab: focus   Space/Return: press   Type to edit   Cmd-Q: quit"
        drawAtPoint:NSMakePoint(24, 218) withAttributes:@{
            NSFontAttributeName: [NSFont systemFontOfSize:12],
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
        }];
}
- (void)mouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (NSPointInRect(point, buttonRect)) [self.host emit:EXAMPLE_CLICK argument:2 shift:NO];
    else if (NSPointInRect(point, fieldRect)) [self.host emit:EXAMPLE_CLICK argument:3 shift:NO];
}
- (void)keyDown:(NSEvent *)event {
    BOOL shift = (event.modifierFlags & NSEventModifierFlagShift) != 0;
    int32_t key = 0;
    if ((event.modifierFlags & NSEventModifierFlagCommand) != 0) {
        if ([event.charactersIgnoringModifiers.lowercaseString isEqualToString:@"a"])
            key = EXAMPLE_SELECT_ALL;
        else { [super keyDown:event]; return; }
    } else {
        switch (event.keyCode) {
            case 48: key = EXAMPLE_TAB; break;
            case 36: case 76: key = EXAMPLE_RETURN; break;
            case 49: key = EXAMPLE_SPACE; break;
            case 51: key = EXAMPLE_BACKSPACE; break;
            case 117: key = EXAMPLE_DELETE; break;
            case 123: key = EXAMPLE_LEFT; break;
            case 124: key = EXAMPLE_RIGHT; break;
            case 115: key = EXAMPLE_HOME; break;
            case 119: key = EXAMPLE_END; break;
            default: break;
        }
    }
    if (key) [self.host emit:EXAMPLE_KEY argument:key shift:shift];
    else if (event.characters.length && !self.host.stopping && self.host.callback) {
        NSData *data = [event.characters dataUsingEncoding:NSUTF8StringEncoding];
        self.host.callback(self.host.userdata, EXAMPLE_TEXT, data.bytes, data.length, 0, shift);
    }
}
@end

@implementation AKExampleHost
- (void)emit:(int32_t)event argument:(int32_t)argument shift:(BOOL)shift {
    assert([NSThread isMainThread]);
    if (!self.stopping && self.callback)
        self.callback(self.userdata, event, NULL, 0, argument, shift);
}
- (void)tick:(NSTimer *)timer {
    (void)timer;
    [self emit:EXAMPLE_TICK argument:0 shift:NO];
}
- (void)requestQuit:(id)sender {
    (void)sender;
    self.stopping = YES;
    [NSApp stop:nil];
    // Wake run even when quit was requested from a timer or delegate callback.
    [NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
        location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0
        context:nil subtype:0 data1:0 data2:0] atStart:NO];
}
- (BOOL)windowShouldClose:(NSWindow *)sender {
    (void)sender;
    [self requestQuit:nil];
    return NO; // Odin must free the adapter BEFORE the host closes the window.
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
    (void)notification;
    [self emit:EXAMPLE_FOCUS argument:self.window.firstResponder == self.view shift:NO];
    self.view.needsDisplay = YES;
}
- (void)windowDidResignKey:(NSNotification *)notification {
    (void)notification;
    [self emit:EXAMPLE_FOCUS argument:0 shift:NO];
    self.view.needsDisplay = YES;
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender;
    [self requestQuit:nil];
    return NSTerminateCancel;
}
@end

bool example_host_is_main_thread(void) { return [NSThread isMainThread]; }

void *example_host_create(example_event_callback callback, void *userdata) {
    assert([NSThread isMainThread]);
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        AKExampleHost *host = [AKExampleHost new];
        host.callback = callback;
        host.userdata = userdata;
        host.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 260)
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
            backing:NSBackingStoreBuffered defer:NO];
        if (!host.window) return NULL;
        host.window.releasedWhenClosed = NO;
        host.window.title = @"Odin AccessKit native macOS example";
        host.view = [[AKExampleView alloc] initWithFrame:NSMakeRect(0, 0, 560, 260)];
        host.view.host = host;
        host.view.buttonText = @"Press me (0)";
        host.view.text = @"";
        host.window.contentView = host.view;
        host.window.delegate = host;
        [host.window center];
        [NSApp setDelegate:host];
        NSMenu *menu = [NSMenu new];
        NSMenuItem *appItem = [NSMenuItem new];
        [menu addItem:appItem];
        NSMenu *appMenu = [NSMenu new];
        NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit"
            action:@selector(requestQuit:) keyEquivalent:@"q"];
        quit.target = host;
        [appMenu addItem:quit];
        appItem.submenu = appMenu;
        NSApp.mainMenu = menu;
        return (__bridge_retained void *)host;
    }
}

void *example_host_window(void *pointer) {
    assert([NSThread isMainThread]);
    AKExampleHost *host = (__bridge AKExampleHost *)pointer;
    return (__bridge void *)host.window;
}

void example_host_present(void *pointer, const char *button, size_t buttonLength,
    const char *text, size_t textLength, uint64_t focus, size_t anchor, size_t caret) {
    assert([NSThread isMainThread]);
    AKExampleHost *host = (__bridge AKExampleHost *)pointer;
    host.view.buttonText = [[NSString alloc] initWithBytes:button length:buttonLength encoding:NSUTF8StringEncoding];
    host.view.text = [[NSString alloc] initWithBytes:text length:textLength encoding:NSUTF8StringEncoding];
    host.view.focusedNode = focus;
    host.view.anchor = anchor;
    host.view.caret = caret;
    host.view.needsDisplay = YES;
}

void example_host_run(void *pointer) {
    assert([NSThread isMainThread]);
    @autoreleasepool {
        AKExampleHost *host = (__bridge AKExampleHost *)pointer;
        [NSApp finishLaunching];
        [host.window makeFirstResponder:host.view];
        [host.window makeKeyAndOrderFront:nil];
        activateApplication();
        host.timer = [NSTimer timerWithTimeInterval:0.01 target:host
            selector:@selector(tick:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:host.timer forMode:NSRunLoopCommonModes];
        [NSApp run];
        [host.timer invalidate];
        host.timer = nil;
    }
}

void example_host_stop(void *pointer) {
    assert([NSThread isMainThread]);
    [(__bridge AKExampleHost *)pointer requestQuit:nil];
}

void example_host_focus(void *pointer) {
    assert([NSThread isMainThread]);
    AKExampleHost *host = (__bridge AKExampleHost *)pointer;
    [host.window makeKeyAndOrderFront:nil];
    [host.window makeFirstResponder:host.view];
}

void example_host_destroy(void *pointer) {
    assert([NSThread isMainThread]);
    @autoreleasepool {
        AKExampleHost *host = (__bridge_transfer AKExampleHost *)pointer;
        host.stopping = YES;
        host.callback = NULL;
        [host.timer invalidate];
        host.window.delegate = nil;
        host.view.host = nil;
        [NSApp setDelegate:nil];
        NSApp.mainMenu = nil;
        [host.window orderOut:nil];
        [host.window close];
    }
}

typedef struct { example_worker_callback callback; void *userdata; } Worker;
static void *runWorker(void *pointer) {
    Worker *worker = pointer;
    worker->callback(worker->userdata);
    return NULL;
}
bool example_host_run_worker(example_worker_callback callback, void *userdata) {
    Worker worker = {callback, userdata};
    pthread_t thread;
    if (pthread_create(&thread, NULL, runWorker, &worker) != 0) return false;
    // The stack-owned arguments must remain alive until this worker finishes.
    if (pthread_join(thread, NULL) != 0) abort();
    return true;
}
