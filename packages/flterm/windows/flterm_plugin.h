#ifndef FLUTTER_PLUGIN_FLTERM_PLUGIN_H_
#define FLUTTER_PLUGIN_FLTERM_PLUGIN_H_

#include <flutter/basic_message_channel.h>
#include <flutter/encodable_value.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>

namespace flterm {

class FltermPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  explicit FltermPlugin(flutter::PluginRegistrarWindows* registrar);
  ~FltermPlugin() override;

  FltermPlugin(const FltermPlugin&) = delete;
  FltermPlugin& operator=(const FltermPlugin&) = delete;

 private:
  static LRESULT CALLBACK WindowSubclassProc(HWND window,
                                             UINT message,
                                             WPARAM wparam,
                                             LPARAM lparam,
                                             UINT_PTR subclass_id,
                                             DWORD_PTR reference_data);

  std::optional<LRESULT> HandleWindowMessage(HWND window,
                                             UINT message,
                                             WPARAM wparam,
                                             LPARAM lparam);
  void SendKeyboardMetadata(UINT message, WPARAM wparam, LPARAM lparam);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::BasicMessageChannel<flutter::EncodableValue>>
      channel_;
  HWND view_window_ = nullptr;
  int window_proc_id_ = -1;
};

}  // namespace flterm

#endif  // FLUTTER_PLUGIN_FLTERM_PLUGIN_H_
