import AppKit
import Carbon
import Combine
import CoreGraphics
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
    private var outsideClickMonitor: Any?
    private var keyboardMonitor: Any?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var targetApplication: NSRunningApplication?

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

        popover.behavior = .applicationDefined
        popover.contentSize = NSSize(width: 360, height: 430)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardHistoryView(
                store: historyStore,
                shortcutSettings: shortcutSettings,
                viewState: viewState
            ) { [weak self] entry in
                self?.selectAndPaste(entry)
            }
        )
        statusItem = item
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard
                    let self,
                    self.popover.isShown,
                    let popoverWindow = self.popover.contentViewController?.view.window
                else { return }
                if !popoverWindow.frame.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation) {
                    self.popover.performClose(nil)
                }
            }
        }

        shortcutSettings.onChange = { [weak self] in
            self?.registerGlobalShortcut()
        }
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                application.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else { return }
            self.targetApplication = application
        }
        installHotKeyHandler()
        installKeyboardMonitor()
        registerGlobalShortcut()
    }

    @objc private func togglePopover() {
        guard statusItem?.button != nil else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
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
                    appDelegate.handleGlobalShortcut()
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
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetApplication = frontmost
        }
        viewState.showingShortcutSettings = false
        viewState.selectedEntryID = historyStore.entries.first?.id
        viewState.pasteNotice = nil
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func handleGlobalShortcut() {
        if popover.isShown {
            if viewState.showingShortcutSettings {
                viewState.showingShortcutSettings = false
            } else {
                popover.performClose(nil)
            }
        } else {
            showPopover()
        }
    }

    private func installKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                self.popover.isShown,
                !self.viewState.showingShortcutSettings,
                event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
            else { return event }

            switch event.keyCode {
            case UInt16(kVK_DownArrow):
                self.moveSelection(by: 1)
                return nil
            case UInt16(kVK_UpArrow):
                self.moveSelection(by: -1)
                return nil
            case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
                if let entry = self.historyStore.entries.first(where: { $0.id == self.viewState.selectedEntryID }) {
                    self.selectAndPaste(entry)
                }
                return nil
            case UInt16(kVK_Escape):
                self.popover.performClose(nil)
                return nil
            default:
                return event
            }
        }
    }

    private func moveSelection(by offset: Int) {
        let entries = historyStore.entries
        guard !entries.isEmpty else { return }

        guard let selectedIndex = entries.firstIndex(where: { $0.id == viewState.selectedEntryID }) else {
            viewState.selectedEntryID = offset > 0 ? entries.first?.id : entries.last?.id
            return
        }

        let nextIndex = min(max(selectedIndex + offset, 0), entries.count - 1)
        viewState.selectedEntryID = entries[nextIndex].id
    }

    private func selectAndPaste(_ entry: ClipboardEntry) {
        historyStore.restore(entry)

        guard let targetApplication, targetApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            viewState.pasteNotice = "已放回剪贴板。请先切到要粘贴的应用，再打开历史记录。"
            return
        }

        guard CGPreflightPostEventAccess() else {
            viewState.pasteNotice = "macOS 需要允许 CopyShelf 发送粘贴按键。授权后再次选择这条记录即可自动粘贴。"
            _ = CGRequestPostEventAccess()
            return
        }

        viewState.pasteNotice = nil
        popover.performClose(nil)
        targetApplication.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak targetApplication] in
            guard let self, let targetApplication, !targetApplication.isTerminated else { return }
            self.postPasteKeystroke()
        }
    }

    private func postPasteKeystroke() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let keyCode = UInt16(kVK_ANSI_V)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    deinit {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
