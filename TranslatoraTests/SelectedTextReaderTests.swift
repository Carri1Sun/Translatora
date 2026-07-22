import AppKit
import Testing
@testable import Translatora

@MainActor
struct SelectedTextReaderTests {
    @Test
    func restoresEveryPasteboardRepresentation() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        let originalItem = NSPasteboardItem()
        originalItem.setString("原始剪贴板", forType: .string)
        originalItem.setData(
            Data("<b>原始剪贴板</b>".utf8),
            forType: .html
        )
        pasteboard.clearContents()
        pasteboard.writeObjects([originalItem])

        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("临时选区", forType: .string)

        snapshot.restore(to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "原始剪贴板")
        #expect(
            pasteboard.data(forType: .html)
                == Data("<b>原始剪贴板</b>".utf8)
        )
    }
}
