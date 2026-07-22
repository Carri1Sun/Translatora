//
//  TranslatoraApp.swift
//  Translatora
//
//  Created by 孙凯一 on 2026/7/22.
//

import SwiftUI

private enum AppWindowID {
    static let main = "main"
}

@main
struct TranslatoraApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        Window("Translatora", id: AppWindowID.main) {
            ContentView()
                .environmentObject(dependencies)
                .preferredColorScheme(dependencies.appearanceStore.appearance.colorScheme)
                .onAppear {
                    dependencies.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 720)
        .commands {
            TranslatoraCommands(dependencies: dependencies)
        }
    }
}

private struct TranslatoraCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var dependencies: AppDependencies

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("设置…") {
                dependencies.presentSettings()
                openWindow(id: AppWindowID.main)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu("翻译") {
            Button("翻译浮窗（\(dependencies.shortcutStore.shortcut.displayName)）") {
                dependencies.toggleTranslationPanel()
            }
        }
    }
}
