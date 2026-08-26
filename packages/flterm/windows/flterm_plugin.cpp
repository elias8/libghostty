#include <windows.h>
#include <commctrl.h>

#include "flterm_plugin.h"

#include <flutter/standard_message_codec.h>

#include <array>
#include <cstdint>
#include <string>
#include <utility>

namespace flterm {
namespace {

constexpr char kChannelName[] = "dev.flterm/native_keyboard";
constexpr UINT_PTR kSubclassId = 0x464C544D;
constexpr int kExtendedScanCode = 0xE000;
constexpr UINT kTranslateWithoutChangingState = 1 << 2;

enum ModBits {
  kShift = 1 << 0,
  kControl = 1 << 1,
  kAlt = 1 << 2,
  kSuper = 1 << 3,
  kCapsLock = 1 << 4,
  kNumLock = 1 << 5,
  kShiftSide = 1 << 6,
  kControlSide = 1 << 7,
  kAltSide = 1 << 8,
  kSuperSide = 1 << 9,
};

bool IsDown(const std::array<BYTE, 256>& state, int key) {
  return (state[key] & 0x80) != 0;
}

bool IsToggled(const std::array<BYTE, 256>& state, int key) {
  return (state[key] & 0x01) != 0;
}

uint16_t ResolveKeyCode(WPARAM wparam, bool extended, uint8_t scan_code) {
  switch (wparam) {
    case VK_SHIFT:
      return static_cast<uint16_t>(
          MapVirtualKey(scan_code, MAPVK_VSC_TO_VK_EX));
    case VK_CONTROL:
      return extended ? VK_RCONTROL : VK_LCONTROL;
    case VK_MENU:
      return extended ? VK_RMENU : VK_LMENU;
    default:
      return static_cast<uint16_t>(wparam);
  }
}

bool IsModifierKey(uint16_t key_code) {
  switch (key_code) {
    case VK_LSHIFT:
    case VK_RSHIFT:
    case VK_LCONTROL:
    case VK_RCONTROL:
    case VK_LMENU:
    case VK_RMENU:
    case VK_LWIN:
    case VK_RWIN:
    case VK_CAPITAL:
    case VK_NUMLOCK:
    case VK_SCROLL:
      return true;
    default:
      return false;
  }
}

int64_t ModifierBits(const std::array<BYTE, 256>& state) {
  int64_t result = 0;
  if (IsDown(state, VK_LSHIFT) || IsDown(state, VK_RSHIFT)) result |= kShift;
  if (IsDown(state, VK_LCONTROL) || IsDown(state, VK_RCONTROL)) {
    result |= kControl;
  }
  if (IsDown(state, VK_LMENU) || IsDown(state, VK_RMENU)) result |= kAlt;
  if (IsDown(state, VK_LWIN) || IsDown(state, VK_RWIN)) result |= kSuper;
  if (IsToggled(state, VK_CAPITAL)) result |= kCapsLock;
  if (IsToggled(state, VK_NUMLOCK)) result |= kNumLock;
  if (IsDown(state, VK_RSHIFT)) result |= kShiftSide;
  if (IsDown(state, VK_RCONTROL)) result |= kControlSide;
  if (IsDown(state, VK_RMENU)) result |= kAltSide;
  if (IsDown(state, VK_RWIN)) result |= kSuperSide;
  return result;
}

struct Translation {
  int result = 0;
  std::wstring text;
};

Translation Translate(uint16_t key_code,
                      uint8_t scan_code,
                      const std::array<BYTE, 256>& state,
                      HKL layout) {
  std::array<wchar_t, 8> buffer{};
  const int result = ToUnicodeEx(
      key_code, scan_code, state.data(), buffer.data(),
      static_cast<int>(buffer.size()), kTranslateWithoutChangingState, layout);
  Translation translation;
  translation.result = result;
  if (result > 0) {
    translation.text.assign(buffer.data(), result);
  }
  return translation;
}

void ClearKey(std::array<BYTE, 256>* state, int key) {
  (*state)[key] = 0;
}

void ClearShift(std::array<BYTE, 256>* state) {
  ClearKey(state, VK_SHIFT);
  ClearKey(state, VK_LSHIFT);
  ClearKey(state, VK_RSHIFT);
}

void ClearControl(std::array<BYTE, 256>* state) {
  ClearKey(state, VK_CONTROL);
  ClearKey(state, VK_LCONTROL);
  ClearKey(state, VK_RCONTROL);
}

void ClearAlt(std::array<BYTE, 256>* state) {
  ClearKey(state, VK_MENU);
  ClearKey(state, VK_LMENU);
  ClearKey(state, VK_RMENU);
}

bool IsPrintable(const std::wstring& text) {
  if (text.empty()) return false;
  for (wchar_t value : text) {
    if (value < 0x20 || value == 0x7F) return false;
  }
  return true;
}

int64_t ConsumedModifierBits(uint16_t key_code,
                             uint8_t scan_code,
                             const std::array<BYTE, 256>& state,
                             HKL layout,
                             const Translation& produced) {
  if (produced.result <= 0 || !IsPrintable(produced.text)) return 0;
  int64_t result = 0;

  if (IsDown(state, VK_LSHIFT) || IsDown(state, VK_RSHIFT)) {
    auto without = state;
    ClearShift(&without);
    if (Translate(key_code, scan_code, without, layout).text != produced.text) {
      result |= kShift;
    }
  }
  if (IsToggled(state, VK_CAPITAL)) {
    auto without = state;
    without[VK_CAPITAL] &= 0xFE;
    if (Translate(key_code, scan_code, without, layout).text != produced.text) {
      result |= kCapsLock;
    }
  }
  if (IsDown(state, VK_RMENU) &&
      (IsDown(state, VK_LCONTROL) || IsDown(state, VK_RCONTROL))) {
    auto without = state;
    ClearControl(&without);
    ClearAlt(&without);
    if (Translate(key_code, scan_code, without, layout).text != produced.text) {
      result |= kControl | kAlt;
    }
  }
  return result;
}

uint32_t SingleCodePoint(const std::wstring& text) {
  if (text.size() == 1) {
    const uint32_t value = text[0];
    if (value < 0x20 || value == 0x7F ||
        (value >= 0xD800 && value <= 0xDFFF)) {
      return 0;
    }
    return value;
  }
  if (text.size() != 2) return 0;
  const uint32_t high = text[0];
  const uint32_t low = text[1];
  if (high < 0xD800 || high > 0xDBFF || low < 0xDC00 || low > 0xDFFF) {
    return 0;
  }
  return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
}

}  // namespace

void FltermPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<FltermPlugin>(registrar));
}

FltermPlugin::FltermPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      channel_(std::make_unique<
               flutter::BasicMessageChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMessageCodec::GetInstance())) {
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowMessage(window, message, wparam, lparam);
      });
  if (auto* view = registrar_->GetView()) {
    view_window_ = view->GetNativeWindow();
    SetWindowSubclass(view_window_, WindowSubclassProc, kSubclassId,
                      reinterpret_cast<DWORD_PTR>(this));
  }
}

FltermPlugin::~FltermPlugin() {
  if (view_window_ != nullptr) {
    RemoveWindowSubclass(view_window_, WindowSubclassProc, kSubclassId);
  }
  if (window_proc_id_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

LRESULT CALLBACK FltermPlugin::WindowSubclassProc(HWND window,
                                                  UINT message,
                                                  WPARAM wparam,
                                                  LPARAM lparam,
                                                  UINT_PTR,
                                                  DWORD_PTR reference_data) {
  auto* plugin = reinterpret_cast<FltermPlugin*>(reference_data);
  plugin->HandleWindowMessage(window, message, wparam, lparam);
  return DefSubclassProc(window, message, wparam, lparam);
}

std::optional<LRESULT> FltermPlugin::HandleWindowMessage(HWND,
                                                         UINT message,
                                                         WPARAM wparam,
                                                         LPARAM lparam) {
  switch (message) {
    case WM_KEYDOWN:
    case WM_SYSKEYDOWN:
    case WM_KEYUP:
    case WM_SYSKEYUP:
      SendKeyboardMetadata(message, wparam, lparam);
      break;
    default:
      break;
  }
  return std::nullopt;
}

void FltermPlugin::SendKeyboardMetadata(UINT message,
                                        WPARAM wparam,
                                        LPARAM lparam) {
  const bool down = message == WM_KEYDOWN || message == WM_SYSKEYDOWN;
  const uint8_t scan_code = static_cast<uint8_t>((lparam >> 16) & 0xFF);
  const bool extended = ((lparam >> 24) & 0x01) != 0;
  const uint16_t key_code = ResolveKeyCode(wparam, extended, scan_code);
  if (wparam == VK_PACKET || IsModifierKey(key_code)) return;

  std::array<BYTE, 256> state{};
  if (!GetKeyboardState(state.data())) return;
  const HKL layout = GetKeyboardLayout(0);
  const Translation produced = Translate(key_code, scan_code, state, layout);

  auto unshifted_state = state;
  ClearShift(&unshifted_state);
  ClearControl(&unshifted_state);
  ClearAlt(&unshifted_state);
  ClearKey(&unshifted_state, VK_LWIN);
  ClearKey(&unshifted_state, VK_RWIN);
  unshifted_state[VK_CAPITAL] &= 0xFE;
  const Translation unshifted =
      Translate(key_code, scan_code, unshifted_state, layout);

  flutter::EncodableMap message_map{
      {flutter::EncodableValue("platform"),
       flutter::EncodableValue("windows")},
      {flutter::EncodableValue("scanCode"),
       flutter::EncodableValue(scan_code |
                               (extended ? kExtendedScanCode : 0))},
      {flutter::EncodableValue("keyCode"),
       flutter::EncodableValue(static_cast<int>(key_code))},
      {flutter::EncodableValue("down"), flutter::EncodableValue(down)},
      {flutter::EncodableValue("eventTime"),
       flutter::EncodableValue(
           static_cast<int64_t>(static_cast<uint32_t>(GetMessageTime())))},
      {flutter::EncodableValue("mods"),
       flutter::EncodableValue(ModifierBits(state))},
      {flutter::EncodableValue("consumedMods"),
       flutter::EncodableValue(ConsumedModifierBits(
           key_code, scan_code, state, layout, produced))},
      {flutter::EncodableValue("unshiftedCodepoint"),
       flutter::EncodableValue(
           static_cast<int64_t>(SingleCodePoint(unshifted.text)))},
      {flutter::EncodableValue("textWithoutAlt"),
       flutter::EncodableValue()},
      {flutter::EncodableValue("deadKey"),
       flutter::EncodableValue(down && produced.result < 0)},
  };
  channel_->Send(flutter::EncodableValue(std::move(message_map)));
}

}  // namespace flterm
