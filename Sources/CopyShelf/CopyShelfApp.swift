import AppKit
import Carbon
import Combine
import SwiftUI

@main
struct CopyShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let historyStore = ClipboardHistoryStore()
    private let shortcutSettings = ShortcutSettings.shared
    private let viewState = ClipboardHistoryViewState()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyHandlerInstalled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        historyStore.startMonitoring()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyShelf")
            button.toolTip = "CopyShelf — 最近复制"
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 430)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardHistoryView(
                store: historyStore,
                shortcutSettings: shortcutSettings,
                viewState: viewState
            ) { [weak self] entry in
                self?.historyStore.restore(entry)
                self?.popover.performClose(nil)
            }
        )
        statusItem = item

        shortcutSettings.onChange = { [weak self] in
            self?.registerGlobalShortcut()
        }
        installHotKeyHandler()
        registerGlobalShortcut()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func installHotKeyHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    appDelegate.showPopover()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        hotKeyHandlerInstalled = status == noErr
        if status != noErr {
            NSLog("CopyShelf could not install the global shortcut handler: %d", status)
            shortcutSettings.setShortcutAvailable(false)
        }
    }

    private func registerGlobalShortcut() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x43505348), id: 1)
        let status = RegisterEventHotKey(
            shortcutSettings.keyCode,
            shortcutSettings.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        shortcutSettings.setShortcutAvailable(status == noErr && hotKeyHandlerInstalled)
        if status != noErr {
            NSLog("CopyShelf could not register shortcut %@: %d", shortcutSettings.displayShortcut, status)
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        viewState.showingShortcutSettings = false
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
