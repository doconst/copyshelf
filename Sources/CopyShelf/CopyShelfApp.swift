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
    private let historyPanel = ClipboardHistoryPanel()
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
            button.action = #selector(toggleHistoryPanel)
        }

        historyPanel.level = .floating
        historyPanel.isFloatingPanel = true
        historyPanel.hidesOnDeactivate = false
        historyPanel.isReleasedWhenClosed = false
        historyPanel.isOpaque = false
        historyPanel.backgroundColor = .clear
        historyPanel.hasShadow = true
        historyPanel.becomesKeyOnlyIfNeeded = false
        historyPanel.contentViewController = NSHostingController(
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
                    self.historyPanel.isVisible
                else { return }
                if !self.historyPanel.frame.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation) {
                    self.closeHistoryPanel(restoreFocus: false)
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
            if self.historyPanel.isVisible {
                self.closeHistoryPanel(restoreFocus: false)
            }
        }
        installHotKeyHandler()
        installKeyboardMonitor()
        registerGlobalShortcut()
    }

    @objc private func toggleHistoryPanel() {
        guard statusItem?.button != nil else { return }

        if historyPanel.isVisible {
            closeHistoryPanel(restoreFocus: true)
        } else {
            showHistoryPanel()
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

    private func showHistoryPanel() {
        guard let button = statusItem?.button else { return }
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetApplication = frontmost
        }
        viewState.showingShortcutSettings = false
        viewState.selectedEntryID = historyStore.entries.first?.id
        viewState.pasteNotice = nil
        let anchorRect = button.convert(button.bounds, to: nil)
        let screenRect = button.window?.convertToScreen(anchorRect)
        let screen = screenRect.flatMap { rect in NSScreen.screens.first { $0.frame.intersects(rect) } } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelSize = historyPanel.frame.size
        let x = min(
            max((screenRect?.midX ?? visibleFrame.midX) - panelSize.width / 2, visibleFrame.minX + 8),
            visibleFrame.maxX - panelSize.width - 8
        )
        let y = min(
            max((screenRect?.minY ?? visibleFrame.maxY) - panelSize.height - 6, visibleFrame.minY + 8),
            visibleFrame.maxY - panelSize.height - 8
        )
        historyPanel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        historyPanel.makeKeyAndOrderFront(nil)
        if let contentView = historyPanel.contentView {
            historyPanel.makeFirstResponder(contentView)
        }
    }

    private func closeHistoryPanel(restoreFocus: Bool) {
        historyPanel.orderOut(nil)
        guard restoreFocus, let targetApplication, !targetApplication.isTerminated else { return }
        targetApplication.activate(options: [.activateAllWindows])
    }

    private func handleGlobalShortcut() {
        if historyPanel.isVisible {
            if viewState.showingShortcutSettings {
                viewState.showingShortcutSettings = false
            } else {
                closeHistoryPanel(restoreFocus: true)
            }
        } else {
            showHistoryPanel()
        }
    }

    private func installKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                self.historyPanel.isVisible,
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
                self.closeHistoryPanel(restoreFocus: true)
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
        historyPanel.orderOut(nil)
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

private final class ClipboardHistoryPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 430),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
