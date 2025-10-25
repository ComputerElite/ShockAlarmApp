#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
//Introduce the source code of this plugin into your own project
#include "webview_cef/webview_cef_plugin_c_api.h"


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
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"shock_alarm_app", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  initCEFProcesses();

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);

    //add this line to enable cef keybord input, and enable to post messages to flutter engine thread from cef message loop thread.
    handleWndProcForCEF(msg.hwnd, msg.message, msg.wParam, msg.lParam);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
