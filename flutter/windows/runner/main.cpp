#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // 1200 by 800, or 90% of the screen when that is smaller, in its middle. The
  // work area is in pixels and Create takes points, so it is scaled down first.
  RECT work{0, 0, 1280, 800};
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0);
  const HMONITOR screen =
      ::MonitorFromPoint(POINT{work.left, work.top}, MONITOR_DEFAULTTOPRIMARY);
  const double scale = FlutterDesktopGetDpiForMonitor(screen) / 96.0;
  const double area_width = (work.right - work.left) / scale;
  const double area_height = (work.bottom - work.top) / scale;
  const double width = std::min(1200.0, area_width * 0.9);
  const double height = std::min(800.0, area_height * 0.9);
  Win32Window::Point origin(
      static_cast<unsigned int>(work.left / scale + (area_width - width) / 2),
      static_cast<unsigned int>(work.top / scale + (area_height - height) / 2));
  Win32Window::Size size(static_cast<unsigned int>(width),
                         static_cast<unsigned int>(height));
  if (!window.Create(L"Nazzil", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
