import Domain
import DomainTestSupport
import Testing

struct ReorderFoldersUseCaseTests {
    @Test func assignsSortIndexByPosition() async throws {
        let a = Folder(name: "A", sortIndex: 0)
        let b = Folder(name: "B", sortIndex: 1)
        let c = Folder(name: "C", sortIndex: 2)
        let repo = InMemoryFolderRepository(folders: [a, b, c])
        try await ReorderFoldersUseCase(folders: repo)(orderedIDs: [c.id, a.id, b.id])
        let order = try await repo.folders().sorted { $0.sortIndex < $1.sortIndex }.map(\.name)
        #expect(order == ["C", "A", "B"])
    }

    @Test func ignoresUnknownIDs() async throws {
        let a = Folder(name: "A", sortIndex: 5)
        let repo = InMemoryFolderRepository(folders: [a])
        try await ReorderFoldersUseCase(folders: repo)(orderedIDs: [Folder.ID(), a.id])
        #expect(try await repo.folders().first?.sortIndex == 1)
    }
}
