import Foundation
@testable import Shared
import Testing

struct InboxWriterTests {
    @Test func copiesFilesAndAvoidsNameClashes() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "InboxWriterTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let writer = InboxWriter(inboxURL: root.appending(path: "Inbox"))
        let source = root.appending(path: "song.mp3")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("abc".utf8).write(to: source)

        let first = try writer.add(source)
        let second = try writer.add(source)
        let third = try writer.add(Data("xyz".utf8), fileName: "song.mp3")

        #expect(first.lastPathComponent == "song.mp3")
        #expect(second.lastPathComponent == "song 2.mp3")
        #expect(third.lastPathComponent == "song 3.mp3")
        #expect(try Data(contentsOf: third) == Data("xyz".utf8))
    }
}
