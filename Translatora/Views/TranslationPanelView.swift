import SwiftUI

struct TranslationPanelView: View {
    @ObservedObject var viewModel: TranslationPanelViewModel
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var shortcutStore: ShortcutStore
    @ObservedObject var pronunciationService: PronunciationService
    let onClose: () -> Void
    let onSaved: (DictionaryEntry) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            header
            languageBar
            inputArea
            phaseContent
        }
        .padding(24)
        .frame(minWidth: 520, maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(panelBackground)
        .preferredColorScheme(appearanceStore.appearance.colorScheme)
        .onAppear {
            inputFocused = true
        }
        .onChange(of: viewModel.inputText) { _, _ in
            viewModel.inputDidChange()
        }
        .onChange(of: viewModel.sourceLanguage) { _, _ in
            viewModel.translationOptionsDidChange()
        }
        .onChange(of: viewModel.targetLanguage) { _, _ in
            viewModel.translationOptionsDidChange()
        }
        .onExitCommand(perform: onClose)
        .alert("无法播放读音", isPresented: pronunciationErrorBinding) {
            Button("好", role: .cancel) {
                pronunciationService.dismissError()
            }
        } message: {
            Text(pronunciationService.errorMessage ?? "未知错误")
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: viewModel.phase)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.accent)
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("翻译浮窗")
                    .font(.headline)
                Text("Translatora")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(shortcutStore.translationShortcut?.spacedDisplayName ?? "未设置")
                .font(.caption.monospaced())
                .foregroundStyle(mutedColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.primary.opacity(0.055), in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(AppIconButtonStyle())
            .help("关闭 (Esc)")
        }
    }

    private var languageBar: some View {
        HStack(spacing: 10) {
            languagePicker(title: "源语言", selection: $viewModel.sourceLanguage)

            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(AppIconButtonStyle())
            .disabled(viewModel.phase == .loading)
            .help("交换语言")

            languagePicker(title: "目标语言", selection: $viewModel.targetLanguage)
        }
    }

    private func languagePicker(
        title: String,
        selection: Binding<TranslationLanguage>
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(TranslationLanguage.allCases) { language in
                Text(language.displayName).tag(language)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
    }

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 14) {
            TextField("输入要翻译的文本…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .lineLimit(3...6)
                .focused($inputFocused)
                .onSubmit {
                    viewModel.translate()
                }

            Button {
                viewModel.translate()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(AppAccentCircleButtonStyle())
            .disabled(!viewModel.canTranslate)
            .keyboardShortcut(.return, modifiers: [])
            .help("翻译 (Return)")
        }
        .padding(16)
        .background(AppTheme.raisedSurface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    inputFocused
                        ? AppTheme.accentDeep.opacity(0.5)
                        : Color.primary.opacity(0.1),
                    lineWidth: inputFocused ? 1.5 : 1
                )
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch viewModel.phase {
        case .idle:
            HStack(spacing: 6) {
                Image(systemName: "selection.pin.in.out")
                Text(idleDescription)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .transition(.opacity)

        case .loading:
            loadingView
                .transition(.scale(scale: 0.96).combined(with: .opacity))

        case let .result(result):
            resultView(result)
                .transition(.move(edge: .bottom).combined(with: .opacity))

        case let .failure(message):
            failureView(message)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    private var loadingView: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.small)
                .tint(AppTheme.accentDeep)

            VStack(alignment: .leading, spacing: 3) {
                Text("正在理解并翻译")
                    .font(.subheadline.weight(.medium))
                Text("模型正在组织自然的表达与例句…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.accent.opacity(0.1), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accentDeep.opacity(0.14), lineWidth: 1)
        }
    }

    private func resultView(_ result: TranslationResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("翻译结果")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accentDeep)

                        Spacer()

                        PronunciationButton(
                            service: pronunciationService,
                            text: viewModel.inputText,
                            language: viewModel.sourceLanguage
                        )
                    }
                    Text(result.translation)
                        .font(.system(size: 20, weight: .medium))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !result.examples.isEmpty {
                    Divider()
                        .opacity(0.55)

                    VStack(alignment: .leading, spacing: 12) {
                        Label("例句", systemImage: "text.quote")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(mutedColor)

                        ForEach(result.examples) { example in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(example.source)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                                Text(example.translation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                HStack {
                    if let message = viewModel.saveErrorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        saveResult()
                    } label: {
                        Label(
                            viewModel.isSaved ? "已保存到词典" : "保存到词典",
                            systemImage: viewModel.isSaved ? "checkmark" : "bookmark"
                        )
                    }
                    .buttonStyle(AppAccentCapsuleButtonStyle())
                    .disabled(viewModel.isSaved)
                    .help(saveButtonHelp)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.automatic)
        .background(AppTheme.raisedSurface, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        }
    }

    private func failureView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button("重试") {
                viewModel.translate()
            }
            .buttonStyle(AppButtonStyle())
        }
        .padding(16)
        .background(AppTheme.raisedSurface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        }
    }

    private var panelBackground: some View {
        ZStack {
            GaussianBlurBackground(
                material: .hudWindow,
                blendingMode: .behindWindow
            )
            AppTheme.panelTint(for: colorScheme)
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 430
            )
        }
        .ignoresSafeArea()
    }

    private var mutedColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.68) : Color.secondary
    }

    private var idleDescription: String {
        if let shortcut = shortcutStore.translationShortcut {
            return "选中文本后按 \(shortcut.displayName)，可直接开始翻译"
        }
        return "输入文本后按 Return 开始翻译"
    }

    private var saveButtonHelp: String {
        if let shortcut = shortcutStore.saveShortcut {
            return "保存到词典 (\(shortcut.displayName))"
        }
        return "保存到词典"
    }

    private func saveResult() {
        guard let entry = viewModel.saveResult() else { return }
        onSaved(entry)
    }

    private var pronunciationErrorBinding: Binding<Bool> {
        Binding(
            get: { pronunciationService.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    pronunciationService.dismissError()
                }
            }
        )
    }
}
