import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var menuBarStore: MenuBarStore
    @ObservedObject var shortcutStore: ShortcutStore
    let shortcutErrorMessage: String?
    let updateTranslationShortcut: (GlobalShortcut?) -> Bool
    let updateSaveShortcut: (GlobalShortcut?) -> Bool
    let selectedTextReader: SelectedTextReader

    @State private var isAccessibilityTrusted = false
    @State private var shortcutValidationError: String?

    var body: some View {
        Form {
            Section("外观") {
                Picker("显示模式", selection: appearanceBinding) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(appearance.displayName, systemImage: appearance.icon)
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Text("翻译浮窗和词汇列表会同步使用所选外观。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("菜单栏") {
                Toggle("显示菜单栏图标", isOn: menuBarVisibilityBinding)

                Text("隐藏后仍可通过应用首页的设置重新开启，Dock 中的 Translatora 也会继续保留。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("快捷键") {
                shortcutRow(
                    title: "打开翻译浮窗",
                    shortcut: shortcutStore.translationShortcut,
                    onChange: applyTranslationShortcut,
                    onDelete: { applyTranslationShortcut(nil) }
                )

                shortcutRow(
                    title: "保存词汇到词典",
                    shortcut: shortcutStore.saveShortcut,
                    onChange: applySaveShortcut,
                    onDelete: { applySaveShortcut(nil) }
                )

                Text("点击快捷键后直接按下新的组合；组合中至少需要一个修饰键。保存快捷键仅在翻译浮窗中生效，按 Esc 可取消录制。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = shortcutValidationError ?? shortcutErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("选中文本") {
                HStack {
                    Label(
                        isAccessibilityTrusted ? "已获得辅助功能权限" : "需要辅助功能权限",
                        systemImage: isAccessibilityTrusted
                            ? "checkmark.shield.fill"
                            : "lock.shield"
                    )
                    .foregroundStyle(isAccessibilityTrusted ? AppTheme.accentDeep : .secondary)

                    Spacer()

                    if !isAccessibilityTrusted {
                        Button("请求权限") {
                            requestAccessibilityAccess()
                        }
                    }

                    Button("系统设置") {
                        selectedTextReader.openAccessibilitySettings()
                    }
                }

                Text(accessibilityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(appearanceStore.appearance.colorScheme)
        .onAppear(perform: refreshAccessibilityStatus)
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { appearanceStore.appearance },
            set: appearanceStore.setAppearance
        )
    }

    private var menuBarVisibilityBinding: Binding<Bool> {
        Binding(
            get: { menuBarStore.isVisible },
            set: menuBarStore.setVisible
        )
    }

    private var accessibilityDescription: String {
        if let shortcut = shortcutStore.translationShortcut {
            return "用于在按下 \(shortcut.displayName) 时读取其他应用当前选中的文本；权限缺失不会影响手动输入翻译。"
        }
        return "用于从其他应用读取当前选中的文本；当前未设置打开翻译浮窗的快捷键，仍可从应用菜单手动打开。"
    }

    private func shortcutRow(
        title: String,
        shortcut: GlobalShortcut?,
        onChange: @escaping (GlobalShortcut) -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)

            Spacer()

            ShortcutRecorderView(
                shortcut: shortcut,
                onChange: onChange,
                onValidationError: { message in
                    shortcutValidationError = message
                }
            )
            .frame(width: 190)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .disabled(shortcut == nil)
            .help("删除快捷键")
        }
    }

    private func requestAccessibilityAccess() {
        isAccessibilityTrusted = selectedTextReader.requestAccessibilityAccess()
        if !isAccessibilityTrusted {
            selectedTextReader.openAccessibilitySettings()
        }
    }

    private func refreshAccessibilityStatus() {
        isAccessibilityTrusted = selectedTextReader.isAccessibilityTrusted
    }

    private func applyTranslationShortcut(_ shortcut: GlobalShortcut?) {
        shortcutValidationError = nil
        _ = updateTranslationShortcut(shortcut)
    }

    private func applySaveShortcut(_ shortcut: GlobalShortcut?) {
        shortcutValidationError = nil
        _ = updateSaveShortcut(shortcut)
    }
}

#Preview {
    GeneralSettingsView(
        appearanceStore: AppearanceStore(),
        menuBarStore: MenuBarStore(),
        shortcutStore: ShortcutStore(),
        shortcutErrorMessage: nil,
        updateTranslationShortcut: { _ in true },
        updateSaveShortcut: { _ in true },
        selectedTextReader: SelectedTextReader()
    )
    .frame(width: 540, height: 560)
}
