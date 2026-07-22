import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        DictionaryHomeView(
            dictionaryStore: dependencies.dictionaryStore,
            shortcutStore: dependencies.shortcutStore,
            shortcutErrorMessage: dependencies.shortcutErrorMessage
        )
    }
}

struct DictionaryHomeView: View {
    @ObservedObject var dictionaryStore: DictionaryStore
    @ObservedObject var shortcutStore: ShortcutStore
    let shortcutErrorMessage: String?

    @State private var editingEntry: DictionaryEntry?
    @State private var entryPendingDeletion: DictionaryEntry?
    @State private var operationErrorMessage: String?

    var body: some View {
        ZStack {
            pageBackground

            VStack(spacing: 0) {
                header

                if dictionaryStore.entries.isEmpty {
                    emptyState
                } else {
                    dictionaryGrid
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .sheet(item: $editingEntry) { entry in
            DictionaryEntryEditorView(entry: entry) { updatedEntry in
                update(updatedEntry)
            }
        }
        .confirmationDialog(
            "删除这条词典记录？",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                deletePendingEntry()
            }
            Button("取消", role: .cancel) {
                entryPendingDeletion = nil
            }
        } message: {
            Text("此操作无法撤销，但不会影响其他词典记录。")
        }
        .alert(
            "无法完成操作",
            isPresented: Binding(
                get: { operationErrorMessage != nil },
                set: { if !$0 { operationErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(operationErrorMessage ?? "未知错误")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.accent)
                        .frame(width: 14, height: 28)

                    Text("我的词典")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }

                Text(dictionaryStore.entries.isEmpty
                     ? "收藏值得记住的表达"
                     : "已收藏 \(dictionaryStore.entries.count) 条翻译")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let shortcutErrorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(shortcutErrorMessage)
            }

            SettingsLink {
                Image(systemName: "gearshape")
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.primary)
                    .padding(7)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .help("设置")
        }
        .padding(.horizontal, 30)
        .padding(.top, 26)
        .padding(.bottom, 22)
    }

    private var dictionaryGrid: some View {
        ScrollView {
            CardFlowLayout(spacing: 16) {
                ForEach(dictionaryStore.entries) { entry in
                    DictionaryCardView(
                        entry: entry,
                        onEdit: { editingEntry = entry },
                        onDelete: { entryPendingDeletion = entry }
                    )
                    .frame(width: 286)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
            .animation(.spring(response: 0.46, dampingFraction: 0.88), value: dictionaryStore.entries)
        }
        .scrollIndicators(.never)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.18))
                    .frame(width: 112, height: 112)
                Image(systemName: "character.book.closed")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(AppTheme.accentDeep)
            }
            .glassEffect(.regular, in: .circle)

            VStack(spacing: 7) {
                Text("词典还是空的")
                    .font(.title3.weight(.semibold))
                Text("选中任意文本后按下 \(shortcutStore.shortcut.displayName)，翻译完成再决定是否收藏。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let loadErrorMessage = dictionaryStore.loadErrorMessage {
                Label(loadErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var pageBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.13), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }

    private func update(_ entry: DictionaryEntry) {
        do {
            try dictionaryStore.update(entry)
            editingEntry = nil
        } catch {
            operationErrorMessage = error.localizedDescription
        }
    }

    private func deletePendingEntry() {
        guard let entryPendingDeletion else { return }
        do {
            try dictionaryStore.delete(entryPendingDeletion)
            self.entryPendingDeletion = nil
        } catch {
            operationErrorMessage = error.localizedDescription
        }
    }
}

private struct DictionaryCardView: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(entry.sourceLanguage.displayName) → \(entry.targetLanguage.displayName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentDeep)

                Spacer()

                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(actionColor)
                    }
                    .help("编辑与添加笔记")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(actionColor)
                    }
                    .help("删除")
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0.55)
            }

            Text(entry.sourceText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)

            Text(entry.translatedText)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(5)
                .textSelection(.enabled)

            if !entry.note.isEmpty {
                Label {
                    Text(entry.note)
                        .lineLimit(3)
                } icon: {
                    Image(systemName: "note.text")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.045), in: .rect(cornerRadius: 10))
            }

            HStack {
                Text(entry.updatedAt, format: .dateTime.month().day())
                Spacer()
                if !entry.examples.isEmpty {
                    Label("\(entry.examples.count) 个例句", systemImage: "text.quote")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(18)
        .contentShape(.rect)
        .glassEffect(
            .regular.tint(isHovering ? AppTheme.accent.opacity(0.1) : nil).interactive(),
            in: .rect(cornerRadius: 20)
        )
        .background(.primary.opacity(0.035), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(isHovering ? 0.18 : 0.1), lineWidth: 1)
        }
        .scaleEffect(isHovering ? 1.012 : 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .onTapGesture(perform: onEdit)
    }

    private var actionColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : AppTheme.ink.opacity(0.72)
    }
}

private struct DictionaryEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (DictionaryEntry) -> Void
    @State private var draft: DictionaryEntry

    init(entry: DictionaryEntry, onSave: @escaping (DictionaryEntry) -> Void) {
        _draft = State(initialValue: entry)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("编辑词典条目")
                        .font(.title2.weight(.bold))
                    Text("修改原文、译文，或记录自己的理解。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Picker("源语言", selection: $draft.sourceLanguage) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Picker("目标语言", selection: $draft.targetLanguage) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }

            editorField(title: "原文", text: $draft.sourceText, minHeight: 82)
            editorField(title: "译文", text: $draft.translatedText, minHeight: 82)
            editorField(title: "笔记", text: $draft.note, minHeight: 100, prompt: "添加用法、语境或记忆提示…")

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    onSave(draft)
                }
                .buttonStyle(.glass(.regular.tint(AppTheme.accent).interactive()))
                .keyboardShortcut(.defaultAction)
                .disabled(
                    draft.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || draft.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(26)
        .frame(width: 570)
        .background(.ultraThinMaterial)
    }

    private func editorField(
        title: String,
        text: Binding<String>,
        minHeight: CGFloat,
        prompt: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty, !prompt.isEmpty {
                    Text(prompt)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }
                TextEditor(text: text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
            }
            .padding(8)
            .frame(minHeight: minHeight)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
    }
}

private struct CardFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let availableWidth = proposal.width ?? 900
        let rows = makeRows(maxWidth: availableWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: availableWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = makeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func makeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentItems: [Item] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if proposedWidth > maxWidth, !currentItems.isEmpty {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = []
                currentWidth = 0
                currentHeight = 0
            }

            currentItems.append(Item(subview: subview, size: size))
            currentWidth += (currentItems.count == 1 ? 0 : spacing) + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }

        return rows
    }

    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct Row {
        let items: [Item]
        let height: CGFloat
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDependencies())
}
