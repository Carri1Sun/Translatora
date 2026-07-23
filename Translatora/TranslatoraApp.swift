//
//  TranslatoraApp.swift
//  Translatora
//
//  Created by 孙凯一 on 2026/7/22.
//

import AppKit
import SwiftUI

private enum AppWindowID {
    static let main = "main"
}

@main
struct TranslatoraApp: App {
    @NSApplicationDelegateAdaptor(TranslatoraAppDelegate.self) private var appDelegate
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        Window("Translatora", id: AppWindowID.main) {
            ContentView()
                .environmentObject(dependencies)
                .preferredColorScheme(dependencies.appearanceStore.appearance.colorScheme)
                .background {
                    MainWindowReader { window in
                        dependencies.attachMainWindow(window)
                    }
                }
                .onAppear {
                    dependencies.start()
                    appDelegate.reopenHandler = { [weak dependencies] in
                        _ = dependencies?.showMainWindow()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 720)
        .commands {
            TranslatoraCommands(dependencies: dependencies)
        }

        MenuBarExtra(
            "Translatora",
            systemImage: "character.book.closed.fill",
            isInserted: menuBarVisibility
        ) {
            TranslatoraMenuBar(dependencies: dependencies)
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarVisibility: Binding<Bool> {
        Binding(
            get: { dependencies.menuBarStore.isVisible },
            set: dependencies.menuBarStore.setVisible
        )
    }
}

private struct TranslatoraCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var dependencies: AppDependencies

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("设置…") {
                dependencies.presentSettings()
                showMainWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu("翻译") {
            Button(translationPanelCommandTitle) {
                dependencies.toggleTranslationPanel()
            }
        }
    }

    private func showMainWindow() {
        guard !dependencies.showMainWindow() else { return }
        openWindow(id: AppWindowID.main)
        Task { @MainActor in
            await Task.yield()
            _ = dependencies.showMainWindow()
        }
    }

    private var translationPanelCommandTitle: String {
        guard let shortcut = dependencies.shortcutStore.translationShortcut else {
            return "翻译浮窗"
        }
        return "翻译浮窗（\(shortcut.displayName)）"
    }
}

private struct TranslatoraMenuBar: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var dependencies: AppDependencies

    var body: some View {
        Button("打开翻译浮窗") {
            dependencies.toggleTranslationPanel()
        }

        Button("打开应用首页") {
            showMainWindow()
        }

        Divider()

        Button("在菜单栏隐藏") {
            dependencies.menuBarStore.setVisible(false)
        }

        Divider()

        Button("退出 Translatora") {
            NSApp.terminate(nil)
        }
    }

    private func showMainWindow() {
        guard !dependencies.showMainWindow() else { return }
        openWindow(id: AppWindowID.main)
        Task { @MainActor in
            await Task.yield()
            _ = dependencies.showMainWindow()
        }
    }
}

private final class TranslatoraAppDelegate: NSObject, NSApplicationDelegate {
    var reopenHandler: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        reopenHandler?()
        return true
    }
}

private struct MainWindowReader: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowReadingView {
        let view = WindowReadingView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: WindowReadingView, context: Context) {
        nsView.onResolve = onResolve
        nsView.resolveWindowIfNeeded()
    }
}

private final class WindowReadingView: NSView {
    var onResolve: ((NSWindow) -> Void)?
    private weak var resolvedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resolveWindowIfNeeded()
    }

    func resolveWindowIfNeeded() {
        guard let window, resolvedWindow !== window else { return }
        resolvedWindow = window
        onResolve?(window)
    }
}
