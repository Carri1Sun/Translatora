import SwiftUI
import UniformTypeIdentifiers

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
    @EnvironmentObject private var dependencies: AppDependencies
    @ObservedObject var dictionaryStore: DictionaryStore
    @ObservedObject var shortcutStore: ShortcutStore
    let shortcutErrorMessage: String?

    @State private var selectedEntryID: UUID?
    @State private var operationErrorMessage: String?
    @State private var transferResultMessage: String?
    @State private var exportDocument: DictionaryArchiveDocument?
    @State private var isImporting = false
    @State private var isExporting = false

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

            detailOverlay
            settingsOverlay
        }
        .frame(minWidth: 720, minHeight: 520)
        .animation(.easeInOut(duration: 0.16), value: selectedEntryID != nil)
        .animation(.easeInOut(duration: 0.16), value: dependencies.isSettingsPresented)
        .onChange(of: dependencies.isSettingsPresented) { _, isPresented in
            if isPresented {
                selectedEntryID = nil
            }
        }
        .onAppear(perform: presentRequestedDictionaryEntry)
        .onChange(of: dependencies.requestedDictionaryEntryID) { _, _ in
            presentRequestedDictionaryEntry()
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
        .alert(
            "词汇表",
            isPresented: Binding(
                get: { transferResultMessage != nil },
                set: { if !$0 { transferResultMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(transferResultMessage ?? "")
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Translatora-词汇表备份",
            onCompletion: handleExport
        )
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

            Menu {
                Button("导入词汇表…", systemImage: "square.and.arrow.down") {
                    selectedEntryID = nil
                    isImporting = true
                }

                Button("导出词汇表…", systemImage: "square.and.arrow.up") {
                    prepareExport()
                }
                .disabled(dictionaryStore.entries.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("导入或导出词汇表")

            Button(action: showSettings) {
                Image(systemName: "gearshape")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(AppIconButtonStyle())
            .help("设置")
        }
        .padding(.horizontal, 30)
        .padding(.top, 26)
        .padding(.bottom, 22)
    }

    private var dictionaryGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(dateSections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text(sectionTitle(for: section.date))
                                .font(.headline)

                            Text("\(section.entries.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.primary.opacity(0.06), in: .capsule)

                            Rectangle()
                                .fill(.primary.opacity(0.08))
                                .frame(height: 1)
                        }

                        CardFlowLayout(spacing: 16) {
                            ForEach(section.entries) { entry in
                                DictionaryCardView(
                                    entry: entry,
                                    onOpen: { selectedEntryID = entry.id }
                                )
                                .frame(width: 286)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 12)
            .padding(.bottom, 30)
            .animation(.spring(response: 0.46, dampingFraction: 0.88), value: orderedEntries)
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
            .overlay {
                Circle()
                    .stroke(AppTheme.accentDeep.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: AppTheme.accentDeep.opacity(0.08), radius: 12, y: 4)

            VStack(spacing: 7) {
                Text("词典还是空的")
                    .font(.title3.weight(.semibold))
                Text(emptyStateDescription)
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
                colors: [AppTheme.accent.opacity(0.07), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }

    private var emptyStateDescription: String {
        if let shortcut = shortcutStore.translationShortcut {
            return "选中任意文本后按下 \(shortcut.displayName)，翻译完成再决定是否收藏。"
        }
        return "从“翻译”菜单打开翻译浮窗，翻译完成再决定是否收藏。"
    }

    private var orderedEntries: [DictionaryEntry] {
        dictionaryStore.entries.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private var dateSections: [DictionaryDateSection] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: orderedEntries) {
            calendar.startOfDay(for: $0.createdAt)
        }
        return groups
            .map { DictionaryDateSection(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private var selectedEntry: DictionaryEntry? {
        guard let selectedEntryID else { return nil }
        return orderedEntries.first { $0.id == selectedEntryID }
    }

    @ViewBuilder
    private var detailOverlay: some View {
        ZStack {
            if let entry = selectedEntry,
               let index = orderedEntries.firstIndex(where: { $0.id == entry.id }) {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture {
                        selectedEntryID = nil
                    }
                    .accessibilityHidden(true)
                    .transition(.opacity)

                DictionaryEntryDetailView(
                    entry: entry,
                    position: index + 1,
                    totalCount: orderedEntries.count,
                    canGoPrevious: index > 0,
                    canGoNext: index < orderedEntries.count - 1,
                    onPrevious: { moveSelection(by: -1) },
                    onNext: { moveSelection(by: 1) },
                    onSave: update,
                    onDelete: delete,
                    onClose: { selectedEntryID = nil }
                )
                .id(entry.id)
                .clipShape(.rect(cornerRadius: 22))
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
                .transition(.offset(y: 18).combined(with: .opacity))
            }
        }
        .zIndex(1)
    }

    @ViewBuilder
    private var settingsOverlay: some View {
        ZStack {
            if dependencies.isSettingsPresented {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture(perform: dependencies.dismissSettings)
                    .accessibilityHidden(true)
                    .transition(.opacity)

                SettingsCardView(
                    configurationStore: dependencies.configurationStore,
                    modelProvider: dependencies.modelProvider,
                    appearanceStore: dependencies.appearanceStore,
                    menuBarStore: dependencies.menuBarStore,
                    shortcutStore: dependencies.shortcutStore,
                    shortcutErrorMessage: dependencies.shortcutErrorMessage,
                    updateTranslationShortcut: dependencies.updateTranslationShortcut,
                    updateSaveShortcut: dependencies.updateSaveShortcut,
                    selectedTextReader: dependencies.selectedTextReader,
                    onClose: dependencies.dismissSettings
                )
                .frame(width: 760)
                .frame(maxHeight: 620)
                .clipShape(.rect(cornerRadius: 22))
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
                .padding(24)
                .transition(.offset(y: 18).combined(with: .opacity))
            }
        }
        .zIndex(2)
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(date: .long, time: .omitted)
    }

    private func showSettings() {
        selectedEntryID = nil
        dependencies.presentSettings()
    }

    private func prepareExport() {
        do {
            exportDocument = DictionaryArchiveDocument(data: try dictionaryStore.exportData())
            isExporting = true
        } catch {
            operationErrorMessage = error.localizedDescription
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        exportDocument = nil

        switch result {
        case .success:
            transferResultMessage = "已导出 \(dictionaryStore.entries.count) 条词汇。"
        case let .failure(error):
            guard !isUserCancellation(error) else { return }
            operationErrorMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let summary = try dictionaryStore.importData(Data(contentsOf: url))
                transferResultMessage = [
                    "新增 \(summary.insertedCount) 条",
                    "更新 \(summary.updatedCount) 条",
                    "跳过 \(summary.skippedCount) 条重复或较旧记录"
                ].joined(separator: "，") + "。"
            } catch {
                operationErrorMessage = "导入失败：\(error.localizedDescription)"
            }
        case let .failure(error):
            guard !isUserCancellation(error) else { return }
            operationErrorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        let cocoaError = error as NSError
        return cocoaError.domain == NSCocoaErrorDomain
            && cocoaError.code == NSUserCancelledError
    }

    private func presentRequestedDictionaryEntry() {
        guard let entryID = dependencies.requestedDictionaryEntryID,
              orderedEntries.contains(where: { $0.id == entryID }) else {
            return
        }
        selectedEntryID = entryID
        dependencies.consumeRequestedDictionaryEntry()
    }

    private func moveSelection(by offset: Int) {
        guard let selectedEntryID,
              let currentIndex = orderedEntries.firstIndex(where: { $0.id == selectedEntryID }) else {
            return
        }
        let targetIndex = currentIndex + offset
        guard orderedEntries.indices.contains(targetIndex) else { return }
        self.selectedEntryID = orderedEntries[targetIndex].id
    }

    private func update(_ entry: DictionaryEntry) -> Bool {
        do {
            try dictionaryStore.update(entry)
            selectedEntryID = entry.id
            return true
        } catch {
            operationErrorMessage = error.localizedDescription
            return false
        }
    }

    private func delete(_ entry: DictionaryEntry) -> Bool {
        let entriesBeforeDeletion = orderedEntries
        let deletedIndex = entriesBeforeDeletion.firstIndex { $0.id == entry.id }
        let fallbackID = deletedIndex.flatMap { index -> UUID? in
            if entriesBeforeDeletion.indices.contains(index + 1) {
                return entriesBeforeDeletion[index + 1].id
            }
            if entriesBeforeDeletion.indices.contains(index - 1) {
                return entriesBeforeDeletion[index - 1].id
            }
            return nil
        }

        do {
            try dictionaryStore.delete(entry)
            selectedEntryID = fallbackID
            return true
        } catch {
            operationErrorMessage = error.localizedDescription
            return false
        }
    }
}

private struct DictionaryArchiveDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct DictionaryDateSection: Identifiable {
    let date: Date
    let entries: [DictionaryEntry]

    var id: Date { date }
}

private struct DictionaryCardView: View {
    let entry: DictionaryEntry
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.sourceText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(entry.translatedText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(entry.sourceLanguage.displayName) → \(entry.targetLanguage.displayName)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accentDeep)
                        .fixedSize()
                }

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
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            isHovering
                ? AppTheme.accent.opacity(colorScheme == .dark ? 0.11 : 0.08)
                : AppTheme.raisedSurface,
            in: .rect(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.primary.opacity(isHovering ? 0.14 : 0.08), lineWidth: 1)
        }
        .shadow(
            color: .black.opacity(isHovering ? 0.08 : 0.045),
            radius: isHovering ? 4 : 2,
            y: 1
        )
        .scaleEffect(isHovering ? 1.006 : 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .accessibilityHint("打开词汇详情")
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
