#include "include/flterm/flterm_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flterm_plugin.h"

void FltermPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flterm::FltermPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
