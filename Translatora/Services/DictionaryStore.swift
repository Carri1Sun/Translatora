import Combine
import Foundation

enum DictionaryStoreError: LocalizedError {
    case unableToCreateDirectory
    case unableToSave

    var errorDescription: String? {
        switch self {
        case .unableToCreateDirectory: "无法创建本地词典目录"
        case .unableToSave: "无法保存本地词典"
        }
    }
}

@MainActor
final class DictionaryStore: ObservableObject {
    @Published private(set) var entries: [DictionaryEntry] = []
    @Published private(set) var loadErrorMessage: String?

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        load()
    }

    @discardableResult
    func add(
        sourceText: String,
        translatedText: String,
        sourceLanguage: TranslationLanguage,
        targetLanguage: TranslationLanguage,
        examples: [TranslationExample]
    ) throws -> DictionaryEntry {
        let entry = DictionaryEntry(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            examples: examples
        )
        var updatedEntries = entries
        updatedEntries.insert(entry, at: 0)
        try persist(updatedEntries)
        entries = updatedEntries
        return entry
    }

    func update(_ entry: DictionaryEntry) throws {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updatedEntry = entry
        updatedEntry.updatedAt = .now
        var updatedEntries = entries
        updatedEntries[index] = updatedEntry
        try persist(updatedEntries)
        entries = updatedEntries
    }

    func delete(_ entry: DictionaryEntry) throws {
        let updatedEntries = entries.filter { $0.id != entry.id }
        try persist(updatedEntries)
        entries = updatedEntries
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            entries = try decoder.decode([DictionaryEntry].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            loadErrorMessage = "本地词典读取失败：\(error.localizedDescription)"
        }
    }

    private func persist(_ entries: [DictionaryEntry]) throws {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw DictionaryStoreError.unableToCreateDirectory
        }

        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw DictionaryStoreError.unableToSave
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory
        return root
            .appending(path: "Translatora", directoryHint: .isDirectory)
            .appending(path: "dictionary.json", directoryHint: .notDirectory)
    }
}
