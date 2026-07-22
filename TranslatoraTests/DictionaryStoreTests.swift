import Foundation
import Testing
@testable import Translatora

@MainActor
struct DictionaryStoreTests {
    @Test
    func persistsUpdatesAndDeletesEntries() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TranslatoraTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "dictionary.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = DictionaryStore(fileURL: fileURL)
        var entry = try store.add(
            sourceText: "serendipity",
            translatedText: "意外发现美好事物的幸运",
            sourceLanguage: .english,
            targetLanguage: .simplifiedChinese,
            examples: [
                TranslationExample(
                    source: "We met by serendipity.",
                    translation: "我们的相遇是一场美好的偶然。"
                )
            ]
        )

        #expect(store.entries.count == 1)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        entry.note = "适合描述偶然的美好发现"
        try store.update(entry)

        let reloadedStore = DictionaryStore(fileURL: fileURL)
        #expect(reloadedStore.entries.first?.note == "适合描述偶然的美好发现")
        #expect(reloadedStore.entries.first?.examples.count == 1)

        if let reloadedEntry = reloadedStore.entries.first {
            try reloadedStore.delete(reloadedEntry)
        }
        #expect(reloadedStore.entries.isEmpty)
        #expect(DictionaryStore(fileURL: fileURL).entries.isEmpty)
    }
}
