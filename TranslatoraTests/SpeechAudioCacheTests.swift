import Foundation
import Testing
@testable import Translatora

struct SpeechAudioCacheTests {
    @Test
    func storesAudioByTrimmedTextSHA256AndClearsIt() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appending(
            path: "SpeechAudioCacheTests.\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let cache = SpeechAudioCache(directoryURL: directoryURL)

        #expect(
            SpeechAudioCache.identifier(for: "  hello  ")
                == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )

        let storedURL = try await cache.store(Data([1, 2, 3, 4]), for: " hello ")
        #expect(
            storedURL.lastPathComponent
                == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824.mp3"
        )
        #expect(await cache.cachedFileURL(for: "hello") == storedURL)
        #expect(try await cache.sizeInBytes() == 4)

        try await cache.clear()

        #expect(await cache.cachedFileURL(for: "hello") == nil)
        #expect(try await cache.sizeInBytes() == 0)
    }
}
