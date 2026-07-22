import SwiftUI

struct DictionaryEntryDetailView: View {
    let entry: DictionaryEntry
    let position: Int
    let totalCount: Int
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSave: (DictionaryEntry) -> Bool
    let onDelete: (DictionaryEntry) -> Bool
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditing = false

    var body: some View {
        ZStack {
            detailBackground

            if isEditing {
                DictionaryEntryEditorView(
                    entry: entry,
                    onCancel: { setEditing(false) },
                    onSave: { updatedEntry in
                        if onSave(updatedEntry) {
                            setEditing(false)
                        }
                    },
                    onDelete: { entryToDelete in
                        let didDelete = onDelete(entryToDelete)
                        if didDelete {
                            setEditing(false)
                        }
                        return didDelete
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                detailContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 680, height: 660)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: isEditing)
    }

    private var detailContent: some View {
        VStack(spacing: 0) {
            detailHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                    noteSection
                    examplesSection
                    metadataSection
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
            }
            .scrollIndicators(.automatic)
            .background(detailBackground)

            navigationBar
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppTheme.accent)
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("词汇详情")
                    .font(.headline)
                Text("第 \(position) 条，共 \(totalCount) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                setEditing(true)
            } label: {
                Label("编辑", systemImage: "square.and.pencil")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glass(.regular.tint(AppTheme.accent.opacity(0.6)).interactive()))

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
            .contentShape(.circle)
            .glassEffect(.regular.interactive(), in: .circle)
            .help("关闭")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.primary.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.sourceText)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.translatedText)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                languagePill(entry.sourceLanguage.displayName)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                languagePill(entry.targetLanguage.displayName)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.16), .primary.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.22), lineWidth: 1)
        }
    }

    private var noteSection: some View {
        detailSection(title: "笔记", systemImage: "note.text") {
            Text(entry.note.isEmpty ? "暂无笔记" : entry.note)
                .font(.body)
                .foregroundStyle(entry.note.isEmpty ? .tertiary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var examplesSection: some View {
        detailSection(title: "例句", systemImage: "text.quote") {
            if entry.examples.isEmpty {
                Text("暂无例句")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(entry.examples) { example in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(example.source)
                                .font(.body.weight(.medium))
                                .textSelection(.enabled)
                            Text(example.translation)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.primary.opacity(0.04), in: .rect(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private var metadataSection: some View {
        detailSection(title: "记录信息", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    "收藏于 \(entry.createdAt.formatted(date: .long, time: .shortened))",
                    systemImage: "bookmark"
                )
                Label(
                    "更新于 \(entry.updatedAt.formatted(date: .long, time: .shortened))",
                    systemImage: "clock.arrow.circlepath"
                )
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button(action: onPrevious) {
                Label("上一条", systemImage: "chevron.left")
                    .frame(minWidth: 82)
            }
            .buttonStyle(.glass)
            .disabled(!canGoPrevious)

            Spacer()

            Text("\(position) / \(totalCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onNext) {
                Label("下一条", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 82)
            }
            .buttonStyle(.glass)
            .disabled(!canGoNext)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.primary.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var detailBackground: some View {
        ZStack {
            detailSurfaceColor
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }

    private var detailSurfaceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.075, green: 0.085, blue: 0.078)
            : Color(red: 0.975, green: 0.982, blue: 0.972)
    }

    private func languagePill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.accentDeep)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.accent.opacity(0.14), in: .capsule)
    }

    private func detailSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accentDeep)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .background(.primary.opacity(0.02), in: .rect(cornerRadius: 18))
    }

    private func setEditing(_ editing: Bool) {
        withAnimation {
            isEditing = editing
        }
    }
}

private struct DictionaryEntryEditorView: View {
    let entry: DictionaryEntry
    let onCancel: () -> Void
    let onSave: (DictionaryEntry) -> Void
    let onDelete: (DictionaryEntry) -> Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var draft: DictionaryEntry
    @State private var isConfirmingDeletion = false

    init(
        entry: DictionaryEntry,
        onCancel: @escaping () -> Void,
        onSave: @escaping (DictionaryEntry) -> Void,
        onDelete: @escaping (DictionaryEntry) -> Bool
    ) {
        self.entry = entry
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: entry)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    languageEditors
                    editorField(title: "原文", text: $draft.sourceText, minHeight: 88)
                    editorField(title: "译文", text: $draft.translatedText, minHeight: 88)
                    editorField(
                        title: "笔记",
                        text: $draft.note,
                        minHeight: 100,
                        prompt: "添加用法、语境或记忆提示…"
                    )
                    exampleEditors
                    readOnlyMetadata
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
            }
            .scrollIndicators(.automatic)
            .background(editorSurfaceColor)

            editorFooter
        }
        .confirmationDialog(
            "删除这条词汇？",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                _ = onDelete(entry)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这条词汇及其笔记、例句会从本地词典中永久移除。")
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
            .contentShape(.circle)
            .glassEffect(.regular.interactive(), in: .circle)
            .help("返回详情")

            VStack(alignment: .leading, spacing: 2) {
                Text("编辑词汇")
                    .font(.headline)
                Text("修改词汇的完整记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.primary.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var languageEditors: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("语言")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Picker("源语言", selection: $draft.sourceLanguage) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)

                Picker("目标语言", selection: $draft.targetLanguage) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }
        }
    }

    private var exampleEditors: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("例句")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    draft.examples.append(TranslationExample(source: "", translation: ""))
                } label: {
                    Label("添加例句", systemImage: "plus")
                }
                .buttonStyle(.glass)
            }

            if draft.examples.isEmpty {
                Text("暂无例句，可以在这里补充自己的用法。")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach($draft.examples) { $example in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("例句")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.accentDeep)
                            Spacer()
                            Button {
                                draft.examples.removeAll { $0.id == example.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("删除例句")
                        }

                        compactEditorField(title: "原句", text: $example.source)
                        compactEditorField(title: "译文", text: $example.translation)
                    }
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }
        }
    }

    private var readOnlyMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("记录信息")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Label(
                "收藏于 \(entry.createdAt.formatted(date: .long, time: .shortened))",
                systemImage: "bookmark"
            )
            Label(
                "更新于 \(entry.updatedAt.formatted(date: .long, time: .shortened))",
                systemImage: "clock.arrow.circlepath"
            )
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.035), in: .rect(cornerRadius: 14))
    }

    private var editorFooter: some View {
        HStack(spacing: 12) {
            Button("删除词汇", role: .destructive) {
                isConfirmingDeletion = true
            }

            Spacer()

            Button("取消", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button("保存") {
                onSave(draft)
            }
            .buttonStyle(.glass(.regular.tint(AppTheme.accent).interactive()))
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.primary.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var canSave: Bool {
        !draft.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !draft.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && draft.examples.allSatisfy {
            !$0.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !$0.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var editorSurfaceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.075, green: 0.085, blue: 0.078)
            : Color(red: 0.975, green: 0.982, blue: 0.972)
    }

    private func editorField(
        title: String,
        text: Binding<String>,
        minHeight: CGFloat,
        prompt: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private func compactEditorField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(10)
                .background(.primary.opacity(0.04), in: .rect(cornerRadius: 10))
        }
    }
}
