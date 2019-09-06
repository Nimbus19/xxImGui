#include "xxGraphicGL.h"
#include "xxGraphicCGL.h"

#include <dlfcn.h>

#define GL_SILENCE_DEPRECATION
#define CGLCreateContext CGLCreateContext_unused
#define CGLDestroyContext CGLDestroyContext_unused
#define CGLGetPixelFormat CGLGetPixelFormat_unused
#define CGLChoosePixelFormat CGLChoosePixelFormat_unused
#define CGLDestroyPixelFormat CGLDestroyPixelFormat_unused
#define CGLDescribePixelFormat CGLDescribePixelFormat_unused
#define CGLSetCurrentContext CGLSetCurrentContext_unused
#define CGLGetCurrentContext CGLGetCurrentContext_unused
#define CGLFlushDrawable CGLFlushDrawable_unused
#define CGLDisable CGLDisable_unused
#define CGLEnable CGLEnable_unused
#define CGLSetParameter CGLSetParameter_unused
#define CGLGetParameter CGLGetParameter_unused
#include <OpenGL/OpenGL.h>
#undef CGLCreateContext
#undef CGLDestroyContext
#undef CGLGetPixelFormat
#undef CGLChoosePixelFormat
#undef CGLDestroyPixelFormat
#undef CGLDescribePixelFormat
#undef CGLSetCurrentContext
#undef CGLGetCurrentContext
#undef CGLFlushDrawable
#undef CGLDisable
#undef CGLEnable
#undef CGLSetParameter
#undef CGLGetParameter
#include <AppKit/NSWindow.h>
#include <AppKit/NSOpenGL.h>
#include <AppKit/NSOpenGLView.h>
static void*                            g_glLibrary = nullptr;
static NSOpenGLView*                    g_rootView = nil;
static PFNGLGENVERTEXARRAYSOESPROC      glGenVertexArrays;
static PFNGLDELETEVERTEXARRAYSOESPROC   glDeleteVertexArrays;
static PFNGLBINDVERTEXARRAYOESPROC      glBindVertexArray;

//==============================================================================
//  Initialize - CGL
//==============================================================================
static bool cglSymbolFailed = false;
static void* cglSymbol(const char* name, bool* failed)
{
    void* ptr = nullptr;

    if (ptr == nullptr && g_glLibrary)
        ptr = dlsym(g_glLibrary, name);

    if (ptr == nullptr)
        xxLog("CGL", "%s is not found", name);

    cglSymbolFailed |= (ptr == nullptr);
    if (failed)
        (*failed) |= (ptr == nullptr);

    return ptr;
}
#define cglSymbol(var) (void*&)var = cglSymbol(#var, nullptr);
//------------------------------------------------------------------------------
uint64_t glCreateContextCGL(uint64_t instance, void* view, void** display)
{
    if (g_rootView == nil)
        return 0;
    NSWindow* nsWindow = (__bridge NSWindow*)view;
    if (nsWindow == nil)
        return 0;
    NSView* nsView = [nsWindow contentView];
    if (nsView == nil)
        return 0;
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
        [nsView setWantsBestResolutionOpenGLSurface:YES];
#endif // MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
    NSOpenGLContext* nsContext = [[NSOpenGLContext alloc] initWithFormat:[g_rootView pixelFormat]
                                                            shareContext:[g_rootView openGLContext]];
    if (nsContext == nil)
        return 0;
    [nsContext setView:nsView];
    [nsContext makeCurrentContext];

    int swapInterval = 0;
    [nsContext setValues:&swapInterval forParameter:NSOpenGLContextParameterSwapInterval];

    cglSymbol(glGetIntegerv);
    cglSymbol(glGenVertexArrays);
    cglSymbol(glDeleteVertexArrays);
    cglSymbol(glBindVertexArray);
    if (glGenVertexArrays && glBindVertexArray)
    {
        GLuint vao = 0;
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
    }

    if (display)
    {
        (*display) = (__bridge void*)nsView;
    }

    return reinterpret_cast<uint64_t>((__bridge_retained void*)nsContext);
}
//------------------------------------------------------------------------------
void glDestroyContextCGL(uint64_t context, void* view, void* display)
{
    NSOpenGLContext* nsContext = (__bridge_transfer NSOpenGLContext*)reinterpret_cast<void*>(context);
    if (nsContext == nil)
        return;
    [nsContext makeCurrentContext];
    [nsContext setView:nil];

    if (glGetIntegerv && glDeleteVertexArrays)
    {
        GLuint vao = 0;
        glGetIntegerv(GL_VERTEX_ARRAY_BINDING_OES, (GLint*)&vao);
        glDeleteVertexArrays(1, &vao);
    }

    [NSOpenGLContext clearCurrentContext];
}
//------------------------------------------------------------------------------
void glMakeCurrentContextCGL(uint64_t context, void* display)
{
    NSOpenGLContext* __unsafe_unretained nsContext = (__bridge NSOpenGLContext*)reinterpret_cast<void*>(context);

    [nsContext makeCurrentContext];
}
//------------------------------------------------------------------------------
void glPresentContextCGL(uint64_t context, void* display)
{
    NSOpenGLContext* __unsafe_unretained nsContext = (__bridge NSOpenGLContext*)reinterpret_cast<void*>(context);

    [nsContext flushBuffer];
}
//------------------------------------------------------------------------------
void glGetViewSizeCGL(void* view, unsigned int* width, unsigned int* height)
{
    NSWindow* nsWindow = (__bridge NSWindow*)view;
    NSView* nsView = [nsWindow contentView];

    NSSize size = [nsView convertRectToBacking:[nsView bounds]].size;
    (*width) = size.width;
    (*height) = size.height;
}
//------------------------------------------------------------------------------
PFNGLSHADERSOURCEPROC glShaderSource_;
void glShaderSourceCGL(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length)
{
    const GLchar** replaceString = xxAlloc(const GLchar*, count);
    for (GLsizei i = 0; i < count; ++i)
    {
        const GLchar* var = string[i];
        if (strcmp(var, "#version 100") == 0)
            var = "#version 120";
        if (strncmp(var, "precision", sizeof("precision") - 1) == 0)
            var = "";
        replaceString[i] = var;
    }

    glShaderSource_(shader, count, replaceString, length);

    xxFree(replaceString);
}
//------------------------------------------------------------------------------
uint64_t xxGraphicCreateCGL()
{
    if (g_glLibrary == nullptr)
        g_glLibrary = dlopen("/System/Library/Frameworks/OpenGL.framework/OpenGL", RTLD_LAZY);
    if (g_glLibrary == nullptr)
        return 0;

    NSOpenGLPixelFormatAttribute attributes[] =
    {
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFANoRecovery,
        0
    };

    NSRect rect = CGRectMake(0, 0, 1, 1);
    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    g_rootView = [[NSOpenGLView alloc] initWithFrame:rect
                                         pixelFormat:pixelFormat];
    if (g_rootView == nil)
        return 0;
    [[g_rootView openGLContext] makeCurrentContext];
    NSOpenGLContext* rootContext = [g_rootView openGLContext];

    if (xxGraphicCreateGL(cglSymbol) == false)
    {
        xxGraphicDestroyCGL(reinterpret_cast<uint64_t>(rootContext));
        return 0;
    }

    glCreateContext = glCreateContextCGL;
    glDestroyContext = glDestroyContextCGL;
    glMakeCurrentContext = glMakeCurrentContextCGL;
    glPresentContext = glPresentContextCGL;
    glGetViewSize = glGetViewSizeCGL;

    glShaderSource_ = glShaderSource;
    glShaderSource = glShaderSourceCGL;

    return reinterpret_cast<uint64_t>((__bridge_retained void*)rootContext);
}
//------------------------------------------------------------------------------
void xxGraphicDestroyCGL(uint64_t context)
{
    glDestroyContextCGL(context, 0, nullptr);

    g_rootView = nil;

    if (g_glLibrary)
    {
        dlclose(g_glLibrary);
        g_glLibrary = nullptr;
    }

    xxGraphicDestroyGL();
}
//==============================================================================
