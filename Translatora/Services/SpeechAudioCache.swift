import CryptoKit
import Foundation

actor SpeechAudioCache {
    private let fileManager: FileManager
    let directoryURL: URL

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
    }

    nonisolated static func identifier(for text: String) -> String {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(normalizedText.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func cachedFileURL(for text: String) -> URL? {
        let url = fileURL(for: text)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }
        return url
    }

    func store(_ data: Data, for text: String) throws -> URL {
        try createDirectoryIfNeeded()
        let url = fileURL(for: text)
        try data.write(to: url, options: .atomic)
        return url
    }

    func sizeInBytes() throws -> Int64 {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return 0 }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: keys)
            if values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        for url in try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) {
            try fileManager.removeItem(at: url)
        }
    }

    private func fileURL(for text: String) -> URL {
        directoryURL.appending(
            path: "\(Self.identifier(for: text)).mp3",
            directoryHint: .notDirectory
        )
    }

    private func createDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private nonisolated static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let cachesDirectory = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return cachesDirectory
            .appending(path: "Translatora", directoryHint: .isDirectory)
            .appending(path: "Pronunciation", directoryHint: .isDirectory)
    }
}
