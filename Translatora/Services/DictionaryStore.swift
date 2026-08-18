import Combine
import Foundation

enum DictionaryStoreError: LocalizedError {
    case unableToCreateDirectory
    case unableToSave
    case unableToExport
    case invalidImportFile
    case unsupportedImportVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unableToCreateDirectory: "无法创建本地词典目录"
        case .unableToSave: "无法保存本地词典"
        case .unableToExport: "无法生成词汇表备份"
        case .invalidImportFile: "所选文件不是有效的 Translatora 词汇表"
        case let .unsupportedImportVersion(version):
            "暂不支持此词汇表版本（版本 \(version)）"
        }
    }
}

struct DictionaryImportSummary: Equatable {
    let insertedCount: Int
    let updatedCount: Int
    let skippedCount: Int
}

@MainActor
final class DictionaryStore: ObservableObject {
    private static let archiveFormatVersion = 1

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
        examples: [TranslationExample],
        sourceImageData: Data? = nil,
        screenshotElements: [ScreenshotTranslationElement] = []
    ) throws -> DictionaryEntry {
        let entry = DictionaryEntry(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            examples: examples,
            sourceImageData: sourceImageData,
            screenshotElements: screenshotElements
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

    func exportData(exportedAt: Date = .now) throws -> Data {
        let archive = DictionaryArchive(
            formatVersion: Self.archiveFormatVersion,
            exportedAt: exportedAt,
            entries: entries
        )

        do {
            return try encoder.encode(archive)
        } catch {
            throw DictionaryStoreError.unableToExport
        }
    }

    func importData(_ data: Data) throws -> DictionaryImportSummary {
        let importedEntries = try decodeImportedEntries(from: data)
        let uniqueImportedEntries = importedEntries.reduce(
            into: [DictionaryEntryIdentity: DictionaryEntry]()
        ) {
            currentEntries,
            entry in
            let identity = DictionaryEntryIdentity(entry: entry)
            guard let currentEntry = currentEntries[identity] else {
                currentEntries[identity] = entry
                return
            }
            if entry.updatedAt > currentEntry.updatedAt {
                currentEntries[identity] = entry
            }
        }

        var mergedEntries = entries.reduce(into: [UUID: DictionaryEntry]()) {
            currentEntries,
            entry in
            guard let currentEntry = currentEntries[entry.id] else {
                currentEntries[entry.id] = entry
                return
            }
            if entry.updatedAt > currentEntry.updatedAt {
                currentEntries[entry.id] = entry
            }
        }
        var entryIDByIdentity = mergedEntries.values.reduce(into: [DictionaryEntryIdentity: UUID]()) {
            currentEntries,
            entry in
            let identity = DictionaryEntryIdentity(entry: entry)
            guard let currentID = currentEntries[identity],
                  let currentEntry = mergedEntries[currentID] else {
                currentEntries[identity] = entry.id
                return
            }
            if entry.updatedAt > currentEntry.updatedAt {
                currentEntries[identity] = entry.id
            }
        }
        var insertedCount = 0
        var updatedCount = 0
        var skippedCount = 0

        for var entry in uniqueImportedEntries.values {
            let importedIdentity = DictionaryEntryIdentity(entry: entry)
            let matchingID = mergedEntries[entry.id] != nil
                ? entry.id
                : entryIDByIdentity[importedIdentity]

            guard let matchingID,
                  let existingEntry = mergedEntries[matchingID] else {
                mergedEntries[entry.id] = entry
                entryIDByIdentity[importedIdentity] = entry.id
                insertedCount += 1
                continue
            }

            if entry.updatedAt > existingEntry.updatedAt {
                entryIDByIdentity.removeValue(
                    forKey: DictionaryEntryIdentity(entry: existingEntry)
                )
                entry.id = matchingID
                mergedEntries[matchingID] = entry
                entryIDByIdentity[importedIdentity] = matchingID
                updatedCount += 1
            } else {
                skippedCount += 1
            }
        }

        if insertedCount > 0 || updatedCount > 0 {
            let updatedEntries = mergedEntries.values.sorted { $0.updatedAt > $1.updatedAt }
            try persist(updatedEntries)
            entries = updatedEntries
        }

        return DictionaryImportSummary(
            insertedCount: insertedCount,
            updatedCount: updatedCount,
            skippedCount: skippedCount
        )
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

    private func decodeImportedEntries(from data: Data) throws -> [DictionaryEntry] {
        if let archive = try? decoder.decode(DictionaryArchive.self, from: data) {
            guard archive.formatVersion >= Self.archiveFormatVersion else {
                throw DictionaryStoreError.unsupportedImportVersion(archive.formatVersion)
            }
            return archive.entries
        }

        if let legacyEntries = try? decoder.decode([DictionaryEntry].self, from: data) {
            return legacyEntries
        }

        throw DictionaryStoreError.invalidImportFile
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory
        return root
            .appending(path: "Translatora", directoryHint: .isDirectory)
            .appending(path: "dictionary.json", directoryHint: .notDirectory)
    }
}

private struct DictionaryArchive: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let entries: [DictionaryEntry]

    init(formatVersion: Int, exportedAt: Date, entries: [DictionaryEntry]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = (try? container.decode(Int.self, forKey: .formatVersion)) ?? 1
        exportedAt = (try? container.decode(Date.self, forKey: .exportedAt)) ?? .distantPast
        entries = try container.decode([DictionaryEntry].self, forKey: .entries)
    }
}

private struct DictionaryEntryIdentity: Hashable {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: TranslationLanguage
    let targetLanguage: TranslationLanguage
    let sourceImageData: Data?

    init(entry: DictionaryEntry) {
        sourceText = entry.sourceText
        translatedText = entry.translatedText
        sourceLanguage = entry.sourceLanguage
        targetLanguage = entry.targetLanguage
        sourceImageData = entry.sourceImageData
    }
}
