// dear imgui: standalone example application
// If you are new to dear imgui, see examples/README.txt and documentation at the top of imgui.cpp.

#include <sys/stat.h>

#include "main/Renderer.h"
#include "main/DearImGui.h"

#include <stdio.h>

#if defined(xxMACOS)
#import <Cocoa/Cocoa.h>
#elif defined(xxIOS)
#import <UIKit/UIKit.h>
#endif

//-----------------------------------------------------------------------------------
// ImGuiExampleView
//-----------------------------------------------------------------------------------

#if defined(xxMACOS)
@interface ImGuiExampleView : NSView
@property (nonatomic) NSTimer* animationTimer;
@end
#elif defined(xxIOS)
@interface ImGuiExampleView : UIView
@end
#endif

@implementation ImGuiExampleView

#if defined(xxMACOS)
-(instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];

    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(updateAndDraw) userInfo:nil repeats:YES];

    [self setWantsLayer:YES];
    [self setPostsFrameChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reset) name:NSViewFrameDidChangeNotification object:self];

    return self;
}
#elif defined(xxIOS)
+(Class)layerClass
{
    return [CAMetalLayer class];
}

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateAndDraw)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    return self;
}
#endif

-(void)updateAndDraw
{
    DearImGui::Update((__bridge void*)self);
}

-(void)reset
{
    Renderer::Reset((__bridge void*)[self window]);
}

-(BOOL)acceptsFirstResponder
{
    return (YES);
}

-(BOOL)becomeFirstResponder
{
    return (YES);
}

-(BOOL)resignFirstResponder
{
    return (YES);
}

@end

//-----------------------------------------------------------------------------------
// ImGuiExampleViewController
//-----------------------------------------------------------------------------------

#if defined(xxMACOS)
@interface ImGuiExampleViewController : NSViewController
@end
#elif defined(xxIOS)
@interface ImGuiExampleViewController : UIViewController
@end
#endif

@implementation ImGuiExampleViewController

#if TARGET_OS_OSX

-(void)loadView                         { self.view = [[NSView alloc] init];            }
-(void)keyUp:(NSEvent *)event           { DearImGui::HandleEventOSX((__bridge void*)event, (__bridge void*)self.view);  }
-(void)keyDown:(NSEvent *)event         { DearImGui::HandleEventOSX((__bridge void*)event, (__bridge void*)self.view);  }
-(void)flagsChanged:(NSEvent *)event    { DearImGui::HandleEventOSX((__bridge void*)event, (__bridge void*)self.view);  }
-(void)mouseDown:(NSEvent *)event       { DearImGui::HandleEventOSX((__bridge void*)event, (__bridge void*)self.view);  }
-(void)mouseUp:(NSEvent *)event         { DearImGui::HandleEventOSX((__bridge void*)event, (__bridge void*)self.view);  }
-(void)mouseMoved:(NSEvent *)event      { DearImGui::HandleEventOSX((__bridge void*)event, (__bridge void*)self.view);  }
-(void)mouseDragged:(NSEvent *)event    { DearImGui::HandleEventOSX((__bridge void*)event, (__bridge void*)self.view);  }
-(void)scrollWheel:(NSEvent *)event     { DearImGui::HandleEventOSX((__bridge void*)event, (__bridge void*)self.view);  }

#elif TARGET_OS_IOS

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    Renderer::Reset((__bridge void*)[self.view window], size.width, size.height);
}

// This touch mapping is super cheesy/hacky. We treat any touch on the screen
// as if it were a depressed left mouse button, and we don't bother handling
// multitouch correctly at all. This causes the "cursor" to behave very erratically
// when there are multiple active touches. But for demo purposes, single-touch
// interaction actually works surprisingly well.
-(void)updateIOWithTouchEvent:(UIEvent *)event
{
    float scale = [self.view contentScaleFactor];
    UITouch* anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    touchLocation.x *= scale;
    touchLocation.y *= scale;
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch* touch in event.allTouches)
    {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
        {
            hasActiveTouch = YES;
            break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event];  }
-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event];  }
-(void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event  { [self updateIOWithTouchEvent:event];  }
-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event];  }

#endif

@end

//-----------------------------------------------------------------------------------
// ImGuiExampleAppDelegate
//-----------------------------------------------------------------------------------

#if defined(xxMACOS)
@interface ImGuiExampleAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (nonatomic, readonly) NSWindow* window;
@end
#elif defined(xxIOS)
@interface ImGuiExampleAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow* window;
@end
#endif

@implementation ImGuiExampleAppDelegate
@synthesize window = _window;

#if defined(xxMACOS)
-(void)setupMenu
{
    NSMenu* mainMenuBar = [[NSMenu alloc] init];
    NSMenu* appMenu;
    NSMenuItem* menuItem;

    appMenu = [[NSMenu alloc] initWithTitle:@"Dear ImGui XX Example"];
    menuItem = [appMenu addItemWithTitle:@"Quit Dear ImGui XX Example" action:@selector(terminate:) keyEquivalent:@"q"];
    [menuItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];

    menuItem = [[NSMenuItem alloc] init];
    [menuItem setSubmenu:appMenu];

    [mainMenuBar addItem:menuItem];

    appMenu = nil;
    [NSApp setMainMenu:mainMenuBar];
}


-(NSWindow*)window
{
    if (_window != nil)
        return (_window);

    NSRect viewRect = NSMakeRect(100.0, 100.0, 100.0 + 1280.0, 100 + 720.0);

    _window = [[NSWindow alloc] initWithContentRect:viewRect styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:YES];
    [_window setTitle:@"Dear ImGui XX Example"];
    [_window setAcceptsMouseMovedEvents:YES];
    [_window setOpaque:YES];
    [_window makeKeyAndOrderFront:NSApp];
    [_window setDelegate:self];

    return (_window);
}

-(void)windowWillClose:(NSNotification *)notification
{
    [NSApp terminate:self];
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self initialize];
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    [self shutdown];
}
#elif defined(xxIOS)
-(UIWindow*)window
{
    if (_window != nil)
        return (_window);

    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    return (_window);
}

-(void)applicationDidFinishLaunching:(UIApplication *)application;
{
    [self initialize];
}

-(void)applicationWillTerminate:(UIApplication *)application;
{
    [self shutdown];
}
#endif

-(void)initialize
{
#if defined(xxMACOS)
    float scale = [self.window backingScaleFactor];

    // Make the application a foreground application (else it won't receive keyboard events)
    ProcessSerialNumber psn = {0, kCurrentProcess};
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);

    // Menu
    [self setupMenu];
#elif defined(xxIOS)
    float scale = [[UIScreen mainScreen] nativeScale];
#endif

    ImGuiExampleView* view = [[ImGuiExampleView alloc] initWithFrame:self.window.frame];
#if defined(xxMACOS)
    self.window.contentViewController = [[ImGuiExampleViewController alloc] init];
    self.window.contentViewController.view = view;
    [self.window makeKeyAndOrderFront:NSApp];
#elif defined(xxIOS)
    self.window.rootViewController = [[ImGuiExampleViewController alloc] init];
    self.window.rootViewController.view = view;
    [self.window makeKeyAndVisible];
#endif

    Renderer::Create((__bridge void*)self.window);
    DearImGui::Create((__bridge void*)view, scale);
}

-(void)shutdown
{
    DearImGui::Shutdown();
    Renderer::Shutdown();
}

@end

int main(int argc, char* argv[])
{
#if defined(xxMACOS)
    @autoreleasepool
    {
        NSApp = [NSApplication sharedApplication];
        ImGuiExampleAppDelegate* delegate = [[ImGuiExampleAppDelegate alloc] init];
        [[NSApplication sharedApplication] setDelegate:delegate];
        [NSApp run];
        return NSApplicationMain(argc, (const char**)argv);
    }
#elif defined(xxIOS)
    @autoreleasepool
    {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ImGuiExampleAppDelegate class]));
    }
#endif
}
