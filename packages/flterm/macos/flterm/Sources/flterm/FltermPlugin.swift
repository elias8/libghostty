import Carbon
import Cocoa
import FlutterMacOS

public final class FltermPlugin: NSObject, FlutterPlugin {
    private static let channelName = "dev.flterm/native_keyboard"

    private let channel: FlutterBasicMessageChannel
    private weak var view: NSView?
    private var monitor: Any?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FltermPlugin(
            messenger: registrar.messenger,
            view: registrar.view)
        registrar.publish(instance)
    }

    private init(messenger: FlutterBinaryMessenger, view: NSView?) {
        channel = FlutterBasicMessageChannel(
            name: Self.channelName,
            binaryMessenger: messenger,
            codec: FlutterStandardMessageCodec.sharedInstance())
        self.view = view
        super.init()
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handle(_ event: NSEvent) {
        guard let view,
              let window = view.window,
              event.window === window else {
            return
        }

        let unmodified = terminalText(event.characters(byApplyingModifiers: []))
        let textWithoutAlt = terminalText(
            event.characters(
                byApplyingModifiers: event.modifierFlags.subtracting(.option)))
        let encodedTextWithoutAlt: Any
        if let textWithoutAlt {
            encodedTextWithoutAlt = textWithoutAlt
        } else {
            encodedTextWithoutAlt = NSNull()
        }
        channel.sendMessage([
            "platform": "macos",
            "scanCode": Int(event.keyCode),
            "keyCode": Int(event.keyCode),
            "down": event.type == .keyDown,
            "eventTime": Int((event.timestamp * 1_000_000).rounded()),
            "mods": modifierBits(event.modifierFlags),
            "consumedMods": consumedModifierBits(event),
            "unshiftedCodepoint": singleScalar(unmodified),
            "textWithoutAlt": encodedTextWithoutAlt,
            "deadKey": event.type == .keyDown && isDeadKey(event),
        ])
    }

    private func consumedModifierBits(_ event: NSEvent) -> Int {
        guard let produced = terminalText(event.characters) else { return 0 }
        var result = 0
        let candidates: [(NSEvent.ModifierFlags, Int)] = [
            (.shift, 1 << 0),
            (.option, 1 << 2),
            (.capsLock, 1 << 4),
        ]
        for (flag, bit) in candidates where event.modifierFlags.contains(flag) {
            let without = terminalText(
                event.characters(
                    byApplyingModifiers: event.modifierFlags.subtracting(flag)))
            if without != produced {
                result |= bit
            }
        }
        return result
    }

    private func isDeadKey(_ event: NSEvent) -> Bool {
        guard let unmanagedSource = TISCopyCurrentKeyboardLayoutInputSource() else {
            return (event.characters?.isEmpty ?? true) &&
                !(event.characters(byApplyingModifiers: [])?.isEmpty ?? true)
        }
        let source = unmanagedSource.takeRetainedValue()
        guard let rawLayout = TISGetInputSourceProperty(
            source,
            kTISPropertyUnicodeKeyLayoutData) else {
            return (event.characters?.isEmpty ?? true) &&
                !(event.characters(byApplyingModifiers: [])?.isEmpty ?? true)
        }

        let layoutData = unsafeBitCast(rawLayout, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(layoutData) else { return false }
        let layout = UnsafeRawPointer(bytes)
            .assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let modifiers = UInt32(
            (event.modifierFlags.rawValue >> 16) & 0xFF)
        let status = characters.withUnsafeMutableBufferPointer { buffer in
            UCKeyTranslate(
                layout,
                event.keyCode,
                UInt16(kUCKeyActionDown),
                modifiers,
                UInt32(LMGetKbdType()),
                OptionBits(0),
                &deadKeyState,
                buffer.count,
                &length,
                buffer.baseAddress!)
        }
        return status == noErr && deadKeyState != 0
    }

    private func modifierBits(_ flags: NSEvent.ModifierFlags) -> Int {
        var result = 0
        if flags.contains(.shift) { result |= 1 << 0 }
        if flags.contains(.control) { result |= 1 << 1 }
        if flags.contains(.option) { result |= 1 << 2 }
        if flags.contains(.command) { result |= 1 << 3 }
        if flags.contains(.capsLock) { result |= 1 << 4 }

        let raw = flags.rawValue
        if raw & 0x04 != 0 { result |= 1 << 6 }
        if raw & 0x2000 != 0 { result |= 1 << 7 }
        if raw & 0x40 != 0 { result |= 1 << 8 }
        if raw & 0x10 != 0 { result |= 1 << 9 }
        return result
    }

    private func singleScalar(_ value: String?) -> Int {
        guard let value else { return 0 }
        let scalars = value.unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first else { return 0 }
        return Int(scalar.value)
    }

    private func terminalText(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let scalars = value.unicodeScalars
        if scalars.count == 1, let codepoint = scalars.first?.value {
            if codepoint < 0x20 || codepoint == 0x7F ||
                (codepoint >= 0xF700 && codepoint <= 0xF8FF) {
                return nil
            }
        }
        return value
    }
}
