import AppKit
import Carbon
import Foundation
import SwiftUI

final class ShortcutSettings: ObservableObject {
    static let shared = ShortcutSettings()

    @Published private(set) var keyCode: UInt32
    @Published private(set) var carbonModifiers: UInt32
    @Published private(set) var keyLabel: String
    @Published private(set) var shortcutIsAvailable = true

    var onChange: (() -> Void)?

    private let defaults = UserDefaults.standard

    private init() {
        keyCode = UInt32(defaults.integer(forKey: "shortcut.keyCode"))
        carbonModifiers = UInt32(defaults.integer(forKey: "shortcut.modifiers"))
        keyLabel = defaults.string(forKey: "shortcut.keyLabel") ?? "V"

        let previousDefaultModifiers = UInt32(optionKey | shiftKey)
        let usesPreviousDefault = keyCode == UInt32(kVK_ANSI_V)
            && carbonModifiers == previousDefaultModifiers
            && keyLabel == "V"
        if defaults.object(forKey: "shortcut.keyCode") == nil || usesPreviousDefault {
            keyCode = UInt32(kVK_ANSI_V)
            carbonModifiers = UInt32(controlKey | optionKey)
            keyLabel = "V"
            defaults.set(Int(keyCode), forKey: "shortcut.keyCode")
            defaults.set(Int(carbonModifiers), forKey: "shortcut.modifiers")
            defaults.set(keyLabel, forKey: "shortcut.keyLabel")
        }
    }

    var displayShortcut: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + keyLabel
    }

    func setShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, keyLabel: String) {
        var carbonFlags: UInt32 = 0
        if modifiers.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if modifiers.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if modifiers.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        if modifiers.contains(.command) { carbonFlags |= UInt32(cmdKey) }

        self.keyCode = UInt32(keyCode)
        self.carbonModifiers = carbonFlags
        self.keyLabel = keyLabel
        defaults.set(Int(self.keyCode), forKey: "shortcut.keyCode")
        defaults.set(Int(carbonFlags), forKey: "shortcut.modifiers")
        defaults.set(keyLabel, forKey: "shortcut.keyLabel")
        onChange?()
    }

    func setShortcutAvailable(_ available: Bool) {
        shortcutIsAvailable = available
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @ObservedObject var settings: ShortcutSettings

    func makeNSView(context: Context) -> ShortcutCaptureButton {
        let button = ShortcutCaptureButton()
        update(button)
        return button
    }

    func updateNSView(_ nsView: ShortcutCaptureButton, context: Context) {
        update(nsView)
    }

    private func update(_ button: ShortcutCaptureButton) {
        button.setShortcutTitle(settings.displayShortcut)
        button.onCapture = { keyCode, modifiers, label in
            settings.setShortcut(keyCode: keyCode, modifiers: modifiers, keyLabel: label)
        }
    }
}

final class ShortcutCaptureButton: NSButton {
    private var isRecording = false
    private var shortcutTitle = ""
    var onCapture: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        font = .systemFont(ofSize: 12, weight: .medium)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setShortcutTitle(_ shortcut: String) {
        shortcutTitle = shortcut
        updateTitle()
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        updateTitle()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else {
            return super.performKeyEquivalent(with: event)
        }
        capture(event)
        return true
    }

    private func capture(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            updateTitle()
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }

        isRecording = false
        onCapture?(event.keyCode, modifiers, Self.label(for: event))
        updateTitle()
    }

    private func updateTitle() {
        title = isRecording ? "按下新的快捷键…" : shortcutTitle
    }

    private static func label(for event: NSEvent) -> String {
        switch event.keyCode {
        case UInt16(kVK_Space): return "Space"
        case UInt16(kVK_Return): return "Return"
        case UInt16(kVK_Tab): return "Tab"
        case UInt16(kVK_Delete): return "Delete"
        case UInt16(kVK_LeftArrow): return "←"
        case UInt16(kVK_RightArrow): return "→"
        case UInt16(kVK_DownArrow): return "↓"
        case UInt16(kVK_UpArrow): return "↑"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        }
    }
}
