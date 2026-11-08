import SwiftUI

final class ClipboardHistoryViewState: ObservableObject {
    @Published var showingShortcutSettings = false
    @Published var selectedEntryID: UUID?
    @Published var pasteNotice: String?
}

struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var shortcutSettings: ShortcutSettings
    @ObservedObject var viewState: ClipboardHistoryViewState
    let onSelect: (ClipboardEntry) -> Void

    var body: some View {
        Group {
            if viewState.showingShortcutSettings {
                shortcutSettingsView
            } else {
                historyView
            }
        }
        .frame(width: 360, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let pasteNotice = viewState.pasteNotice {
                Text(pasteNotice)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
            }
            Divider().padding(.vertical, 10)

            if store.entries.isEmpty {
                emptyState
            } else {
                historyList
            }

            Divider().padding(.vertical, 10)
            footer
        }
        .padding(12)
    }

    private var shortcutSettingsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    viewState.showingShortcutSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("返回剪贴板历史")

                Text("设置快捷键")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }

            Divider().padding(.vertical, 14)

            Text("呼出历史记录")
                .font(.system(size: 12, weight: .medium))
            HStack {
                ShortcutRecorder(settings: shortcutSettings)
                    .frame(width: 150, height: 28)
                Spacer()
            }
            .padding(.top, 10)

            Text("点击上方按钮，再按下包含修饰键的组合键。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            if !shortcutSettings.shortcutIsAvailable {
                Text("系统无法注册这个快捷键，请换一个组合键。")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            Spacer()
            Text("默认快捷键：⌃⌥V")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("CopyShelf")
                    .font(.system(size: 14, weight: .semibold))
                Text("最近复制")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewState.showingShortcutSettings = true
            } label: {
                Image(systemName: "keyboard")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("设置呼出历史记录的快捷键")

            if !store.entries.isEmpty {
                Button("清空") {
                    store.clearHistory()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .help("清空已保存的剪贴板历史")
            }
        }
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(store.entries) { entry in
                        Button {
                            viewState.selectedEntryID = entry.id
                            onSelect(entry)
                        } label: {
                            ClipboardHistoryRow(entry: entry)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(viewState.selectedEntryID == entry.id
                                            ? Color.accentColor.opacity(0.18)
                                            : Color(nsColor: .controlBackgroundColor))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("粘贴：\(entry.text)")
                        .id(entry.id)
                    }
                }
                .padding(.vertical, 1)
            }
            .onChange(of: viewState.selectedEntryID) { selectedID in
                guard let selectedID else { return }
                proxy.scrollTo(selectedID, anchor: .center)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("复制的文本会显示在这里")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("↑↓ 选择 · 回车粘贴")
            Spacer()
            Text("\(shortcutSettings.displayShortcut) 呼出")
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
    }
}

private struct ClipboardHistoryRow: View {
    let entry: ClipboardEntry

    private var relativeDate: String {
        RelativeDateTimeFormatter().localizedString(for: entry.copiedAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.text)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(relativeDate)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
