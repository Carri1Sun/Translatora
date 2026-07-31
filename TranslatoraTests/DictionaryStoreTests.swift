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

    @Test
    func exportsAndImportsVersionedArchive() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TranslatoraTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let sourceURL = directory.appending(path: "source.json")
        let destinationURL = directory.appending(path: "destination.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceStore = DictionaryStore(fileURL: sourceURL)
        _ = try sourceStore.add(
            sourceText: "serendipity",
            translatedText: "意外发现美好事物的幸运",
            sourceLanguage: .english,
            targetLanguage: .simplifiedChinese,
            examples: []
        )

        let archiveData = try sourceStore.exportData()
        let archiveObject = try #require(
            JSONSerialization.jsonObject(with: archiveData) as? [String: Any]
        )
        #expect(archiveObject["formatVersion"] as? Int == 1)
        #expect(archiveObject["entries"] as? [[String: Any]] != nil)

        let destinationStore = DictionaryStore(fileURL: destinationURL)
        let summary = try destinationStore.importData(archiveData)

        #expect(summary == DictionaryImportSummary(
            insertedCount: 1,
            updatedCount: 0,
            skippedCount: 0
        ))
        #expect(destinationStore.entries.first?.sourceText == "serendipity")
        #expect(DictionaryStore(fileURL: destinationURL).entries.count == 1)
    }

    @Test
    func importKeepsNewestEntryForID() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TranslatoraTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "dictionary.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = DictionaryStore(fileURL: fileURL)
        var localEntry = try store.add(
            sourceText: "context",
            translatedText: "语境",
            sourceLanguage: .english,
            targetLanguage: .simplifiedChinese,
            examples: []
        )

        var newerEntry = localEntry
        newerEntry.id = UUID()
        newerEntry.note = "来自备份的新笔记"
        newerEntry.updatedAt = localEntry.updatedAt.addingTimeInterval(60)
        let newerSummary = try store.importData(try encodeLegacyEntries([newerEntry]))

        #expect(newerSummary.updatedCount == 1)
        #expect(store.entries.first?.id == localEntry.id)
        #expect(store.entries.first?.note == "来自备份的新笔记")

        localEntry.note = "不应覆盖的新笔记"
        localEntry.updatedAt = newerEntry.updatedAt.addingTimeInterval(-120)
        let olderSummary = try store.importData(try encodeLegacyEntries([localEntry]))

        #expect(olderSummary.skippedCount == 1)
        #expect(store.entries.first?.note == "来自备份的新笔记")
    }

    @Test
    func importsFutureEntriesWithChangedOptionalFields() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TranslatoraTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "dictionary.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let futureArchive = """
        {
          "formatVersion": 8,
          "futureArchiveField": true,
          "entries": [
            {
              "sourceText": "portable",
              "translatedText": "可移植的",
              "sourceLanguage": "english",
              "targetLanguage": "simplifiedChinese",
              "futureEntryField": {
                "level": 2
              }
            }
          ]
        }
        """

        let store = DictionaryStore(fileURL: fileURL)
        let summary = try store.importData(try #require(futureArchive.data(using: .utf8)))
        let importedEntry = try #require(store.entries.first)

        #expect(summary.insertedCount == 1)
        #expect(importedEntry.sourceText == "portable")
        #expect(importedEntry.translatedText == "可移植的")
        #expect(importedEntry.note.isEmpty)
        #expect(importedEntry.examples.isEmpty)

        let repeatedSummary = try store.importData(
            try #require(futureArchive.data(using: .utf8))
        )
        #expect(repeatedSummary.skippedCount == 1)
        #expect(store.entries.count == 1)
    }

    private func encodeLegacyEntries(_ entries: [DictionaryEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }
}
