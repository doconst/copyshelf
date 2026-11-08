import AppKit
import Foundation

struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let copiedAt: Date

    init(text: String, copiedAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.copiedAt = copiedAt
    }
}

final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []

    private let pasteboard = NSPasteboard.general
    private let maximumEntryCount = 100
    private var observedChangeCount = -1
    private var monitoringTimer: Timer?

    private var historyURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CopyShelf", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    init() {
        loadHistory()
    }

    func startMonitoring() {
        guard monitoringTimer == nil else { return }

        captureCurrentClipboard()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.captureCurrentClipboard()
        }
    }

    func restore(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        observedChangeCount = pasteboard.changeCount
        record(entry.text)
    }

    func clearHistory() {
        entries.removeAll()
        persistHistory()
    }

    private func captureCurrentClipboard() {
        guard pasteboard.changeCount != observedChangeCount else { return }
        observedChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        record(text)
    }

    private func record(_ text: String) {
        entries.removeAll { $0.text == text }
        entries.insert(ClipboardEntry(text: text), at: 0)

        if entries.count > maximumEntryCount {
            entries = Array(entries.prefix(maximumEntryCount))
        }

        persistHistory()
    }

    private func loadHistory() {
        guard
            let data = try? Data(contentsOf: historyURL),
            let savedEntries = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else {
            return
        }

        entries = Array(savedEntries.sorted { $0.copiedAt > $1.copiedAt }.prefix(maximumEntryCount))
    }

    private func persistHistory() {
        do {
            let directory = historyURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            NSLog("CopyShelf could not save clipboard history: %@", error.localizedDescription)
        }
    }
}
