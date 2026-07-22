import SwiftUI

struct TranslationPanelView: View {
    @ObservedObject var viewModel: TranslationPanelViewModel
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var shortcutStore: ShortcutStore
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var inputFocused: Bool

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 18) {
                header
                languageBar
                inputArea
                phaseContent
            }
            .padding(24)
        }
        .frame(width: 640)
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

            Text(shortcutStore.shortcut.spacedDisplayName)
                .font(.caption.monospaced())
                .foregroundStyle(mutedColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.primary)
                    .padding(6)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
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
                    .padding(6)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
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
                    .foregroundStyle(AppTheme.ink)
                    .padding(7)
                    .background(AppTheme.accent, in: .circle)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canTranslate)
            .keyboardShortcut(.return, modifiers: [])
            .help("翻译 (Return)")
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch viewModel.phase {
        case .idle:
            HStack(spacing: 6) {
                Image(systemName: "selection.pin.in.out")
                Text("选中文本后按 \(shortcutStore.shortcut.displayName)，可直接开始翻译")
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
                Text("DeepSeek 正在组织自然的表达与例句…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .glassEffect(.regular.tint(AppTheme.accent.opacity(0.14)), in: .rect(cornerRadius: 16))
    }

    private func resultView(_ result: TranslationResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("翻译结果")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accentDeep)
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
                        viewModel.saveResult()
                    } label: {
                        Label(
                            viewModel.isSaved ? "已保存到词典" : "保存到词典",
                            systemImage: viewModel.isSaved ? "checkmark" : "bookmark"
                        )
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(AppTheme.accent, in: .capsule)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaved)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.automatic)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
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
            .buttonStyle(.glass)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var panelBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.17), .clear],
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
}
