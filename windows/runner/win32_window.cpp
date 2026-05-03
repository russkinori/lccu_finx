#include "win32_window.h"

#ifdef _WIN32

#include <cstring>
#include <type_traits>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Uses the SDK-provided value when available, otherwise falls back to the
/// documented attribute value for older SDKs.
constexpr DWORD GetImmersiveDarkModeAttribute() noexcept {
#ifdef DWMWA_USE_IMMERSIVE_DARK_MODE
  return static_cast<DWORD>(DWMWA_USE_IMMERSIVE_DARK_MODE);
#else
  return 20;
#endif
}

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] =
    L"AppsUseLightTheme";

using EnableNonClientDpiScalingFn = BOOL(WINAPI*)(HWND);

// Scale helper to convert logical scalar values to physical values using the
// passed-in scale factor.
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

template <typename To, typename From>
To BitCastValue(const From& source) noexcept {
  static_assert(sizeof(To) == sizeof(From), "BitCastValue size mismatch");
  static_assert(std::is_trivially_copyable_v<To>,
                "To must be trivially copyable");
  static_assert(std::is_trivially_copyable_v<From>,
                "From must be trivially copyable");

  To destination{};
  std::memcpy(&destination, &source, sizeof(To));
  return destination;
}

template <typename T>
T* PointerFromLParam(LPARAM value) noexcept {
  return BitCastValue<T*>(value);
}

template <typename Func>
Func LoadFunction(HMODULE library_handle, const char* function_name) {
  static_assert(std::is_pointer_v<Func>,
                "Func must be a function pointer type");

  const FARPROC proc = GetProcAddress(library_handle, function_name);
  if (proc == nullptr) {
    return nullptr;
  }

  return BitCastValue<Func>(proc);
}

// Dynamically loads EnableNonClientDpiScaling from User32.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_library = LoadLibraryA("User32.dll");
  if (user32_library == nullptr) {
    return;
  }

  if (const auto enable_non_client_dpi_scaling =
          LoadFunction<EnableNonClientDpiScalingFn>(
              user32_library, "EnableNonClientDpiScaling");
      enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }

  FreeLibrary(user32_library);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    static WindowClassRegistrar instance;
    return &instance;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

  void OnWindowObjectCreated() {
    ++active_window_count_;
  }

  void OnWindowObjectDestroyed() {
    if (active_window_count_ > 0) {
      --active_window_count_;
    }
    if (active_window_count_ == 0 && class_registered_) {
      UnregisterWindowClass();
    }
  }

 private:
  WindowClassRegistrar() = default;

  bool class_registered_ = false;
  int active_window_count_ = 0;
};

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = nullptr;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  if (class_registered_) {
    UnregisterClass(kWindowClassName, nullptr);
    class_registered_ = false;
  }
}

Win32Window::Win32Window() {
  WindowClassRegistrar::GetInstance()->OnWindowObjectCreated();
}

Win32Window::~Win32Window() {
  DestroyInternal(false);
  WindowClassRegistrar::GetInstance()->OnWindowObjectDestroyed();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  UINT dpi = 96;
  HDC screen = GetDC(nullptr);
  if (screen != nullptr) {
    dpi = static_cast<UINT>(GetDeviceCaps(screen, LOGPIXELSX));
    ReleaseDC(nullptr, screen);
  }

  const double scale_factor = static_cast<double>(dpi) / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(static_cast<int>(origin.x), scale_factor),
      Scale(static_cast<int>(origin.y), scale_factor),
      Scale(static_cast<int>(size.width), scale_factor),
      Scale(static_cast<int>(size.height), scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (window == nullptr) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    CREATESTRUCT* window_struct = PointerFromLParam<CREATESTRUCT>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     BitCastValue<LONG_PTR>(window_struct->lpCreateParams));

    auto* that =
        static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else {
    auto* that = GetThisFromHandle(window);
    if (that != nullptr) {
      return that->MessageHandler(window, message, wparam, lparam);
    }
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT Win32Window::MessageHandler(HWND hwnd,
                                    UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      if (call_on_destroy_) {
        this->OnDestroy();
      }
      call_on_destroy_ = true;
      window_handle_ = nullptr;
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto* new_rect_size = PointerFromLParam<RECT>(lparam);
      const LONG new_width = new_rect_size->right - new_rect_size->left;
      const LONG new_height = new_rect_size->bottom - new_rect_size->top;

      SetWindowPos(hwnd, nullptr, new_rect_size->left, new_rect_size->top,
                   new_width, new_height, SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }

    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        MoveWindow(child_content_, rect.left, rect.top,
                   rect.right - rect.left, rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(hwnd, message, wparam, lparam);
}

void Win32Window::Destroy() {
  DestroyInternal(true);
}

void Win32Window::DestroyInternal(bool call_on_destroy) {
  call_on_destroy_ = call_on_destroy;

  if (window_handle_ != nullptr) {
    DestroyWindow(window_handle_);
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return BitCastValue<Win32Window*>(GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, TRUE);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame{};
  if (window_handle_ != nullptr) {
    GetClientRect(window_handle_, &frame);
  }
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // Intentionally empty.
  // Subclasses can override this to release window-owned resources.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode = 0;
  DWORD light_mode_size = sizeof(light_mode);
  const LSTATUS result =
      RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                  kGetPreferredBrightnessRegValue, RRF_RT_REG_DWORD, nullptr,
                  &light_mode, &light_mode_size);

  if (result == ERROR_SUCCESS) {
    const BOOL enable_dark_mode = (light_mode == 0);
    const DWORD immersive_dark_mode_attribute =
        GetImmersiveDarkModeAttribute();
    DwmSetWindowAttribute(window, immersive_dark_mode_attribute,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}

#endif  // _WIN32