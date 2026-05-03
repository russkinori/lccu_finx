#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <Windows.h>
#include <dwmapi.h>
#else
typedef void* HWND;
typedef unsigned int UINT;
typedef long LONG;
typedef unsigned long ULONG;
typedef unsigned long DWORD;
typedef int BOOL;
typedef void* HDC;
typedef void* HINSTANCE;
typedef void* HMONITOR;
typedef long long LONG_PTR;
typedef unsigned long long UINT_PTR;
typedef UINT_PTR WPARAM;
typedef LONG_PTR LPARAM;
typedef LONG_PTR LRESULT;

struct POINT {
  LONG x;
  LONG y;
};

struct RECT {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
};

#define APIENTRY
#define CALLBACK
#endif

#include <string>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling.
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Window
  // sizes are specified to the OS in physical pixels, hence to ensure a
  // consistent size this function will scale the input width and height as
  // appropriate for the default monitor. The window is invisible until |Show|
  // is called. Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with the window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Returns a RECT representing the bounds of the current client area.
  RECT GetClientArea();

 protected:
  // Processes and routes salient window messages for mouse handling,
  // size change, and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when Create is called, allowing subclass window-related setup.
  // Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when the native window is being destroyed.
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // OS callback called by the message pump. Handles the WM_NCCREATE message,
  // which is passed when the non-client area is being created, and enables
  // automatic non-client DPI scaling so that the non-client area responds to
  // changes in DPI. All other messages are handled by MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|.
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Update the window frame's theme to match the system theme.
  static void UpdateTheme(HWND const window);

  // Shared destruction path. When |call_on_destroy| is false, subclass destroy
  // callbacks are suppressed so that destruction from the base destructor does
  // not rely on virtual dispatch.
  void DestroyInternal(bool call_on_destroy);

  bool quit_on_close_ = false;
  bool call_on_destroy_ = true;

  // Window handle for top-level window.
  HWND window_handle_ = nullptr;

  // Window handle for hosted content.
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_