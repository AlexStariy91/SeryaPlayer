import Domain
import Foundation
@testable import PlayerFeature
import Testing

@MainActor
struct PlaybackProgressTests {
    @Test func tickReadsThePlayer() {
        let player = RecordingPlayer()
        let progress = PlaybackProgress(player: player)
        player.currentTime = 12.5

        progress.tick()

        #expect(progress.currentTime == 12.5)
    }

    @Test func tinyChangesAreIgnored() {
        let player = RecordingPlayer()
        let progress = PlaybackProgress(player: player)
        player.currentTime = 10
        progress.tick()
        player.currentTime = 10.01

        progress.tick()

        #expect(progress.currentTime == 10)
    }

    @Test func seekUpdatesImmediately() {
        let player = RecordingPlayer()
        let progress = PlaybackProgress(player: player)

        progress.seek(to: 42)

        #expect(progress.currentTime == 42)
        #expect(player.calls == [.seek(42)])
    }

    @Test func runPollsUntilCancelled() async {
        let player = RecordingPlayer()
        let progress = PlaybackProgress(player: player, interval: .milliseconds(5))
        let task = Task { await progress.run() }

        player.currentTime = 3
        #expect(await waitUntilAsync { progress.currentTime == 3 })

        task.cancel()
        await task.value
        player.currentTime = 9
        try? await Task.sleep(for: .milliseconds(30))
        #expect(progress.currentTime == 3)
    }

    private func waitUntilAsync(_ condition: @MainActor () -> Bool) async -> Bool {
        for _ in 0 ..< 200 {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }
}
