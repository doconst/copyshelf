import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardHistoryStore
    let onSelect: (ClipboardEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
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
        .frame(width: 360, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
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
        ScrollView {
            LazyVStack(spacing: 5) {
                ForEach(store.entries) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        ClipboardHistoryRow(entry: entry)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("复制：\(entry.text)")
                }
            }
            .padding(.vertical, 1)
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
            Text("点击条目放回剪贴板")
            Spacer()
            Text("纯文本 · 本机保存")
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
