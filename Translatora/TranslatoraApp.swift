//
//  TranslatoraApp.swift
//  Translatora
//
//  Created by 孙凯一 on 2026/7/22.
//

import SwiftUI

@main
struct TranslatoraApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
                .preferredColorScheme(dependencies.appearanceStore.appearance.colorScheme)
                .onAppear {
                    dependencies.start()
                }
        }
        .defaultSize(width: 980, height: 720)

        Settings {
            DeepSeekSettingsView(
                configurationStore: dependencies.configurationStore,
                modelProvider: dependencies.modelProvider,
                appearanceStore: dependencies.appearanceStore,
                shortcutStore: dependencies.shortcutStore,
                shortcutErrorMessage: dependencies.shortcutErrorMessage,
                updateShortcut: dependencies.updateGlobalShortcut,
                selectedTextReader: dependencies.selectedTextReader
            )
            .preferredColorScheme(dependencies.appearanceStore.appearance.colorScheme)
        }

        .commands {
            CommandMenu("翻译") {
                Button("翻译浮窗（\(dependencies.shortcutStore.shortcut.displayName)）") {
                    dependencies.toggleTranslationPanel()
                }
            }
        }
    }
}
