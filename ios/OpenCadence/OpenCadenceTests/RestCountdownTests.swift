import AVFoundation
import Foundation
import Testing
@testable import OpenCadence

struct RestCountdownTests {
    private let deadline = Date(timeIntervalSince1970: 1_000)

    @Test("The final three seconds and the ready cue share the persisted deadline")
    func countdownTiming() {
        let cues = RestCountdownCue.upcoming(until: deadline, now: deadline.addingTimeInterval(-30))
        #expect(cues.map(\.secondsRemaining) == [3, 2, 1, 0])
        #expect(cues.map { $0.date.timeIntervalSince(deadline) } == [-3, -2, -1, 0])
    }

    @Test("Returning during or after the countdown never replays missed seconds")
    func lateReturn() {
        #expect(RestCountdownCue.upcoming(until: deadline, now: deadline.addingTimeInterval(-1.4))
            .map(\.secondsRemaining) == [1, 0])
        #expect(RestCountdownCue.upcoming(until: deadline, now: deadline).isEmpty)
        #expect(RestCountdownCue.upcoming(until: deadline, now: deadline.addingTimeInterval(20)).isEmpty)
    }

    @Test("Delayed wakeups cannot produce a burst of stale sounds")
    func delayedWakeup() {
        let cue = RestCountdownCue(secondsRemaining: 2, date: deadline.addingTimeInterval(-2))
        #expect(cue.isTimely(at: cue.date.addingTimeInterval(0.05)))
        #expect(!cue.isTimely(at: cue.date.addingTimeInterval(-0.01)))
        #expect(!cue.isTimely(at: cue.date.addingTimeInterval(0.3)))
        #expect(!cue.isTimely(at: deadline))
    }

    @Test("Restarting uses the new deadline instead of the old countdown")
    func restartedRest() {
        let now = deadline.addingTimeInterval(-2)
        let restarted = now.addingTimeInterval(60)
        let cues = RestCountdownCue.upcoming(until: restarted, now: now)
        #expect(cues.first?.date == now.addingTimeInterval(57))
        #expect(cues.last?.date == restarted)
    }

    @MainActor
    @Test("Both short sound files are bundled and decode as audio")
    func bundledSounds() throws {
        let bundle = Bundle(for: ActiveWorkoutRecord.self)
        let tick = try AVAudioPlayer(contentsOf: #require(bundle.url(forResource: "rest-tick", withExtension: "wav")))
        let ready = try AVAudioPlayer(contentsOf: #require(bundle.url(forResource: "rest-ready", withExtension: "wav")))
        #expect((0.05..<0.15).contains(tick.duration))
        #expect((0.2..<0.4).contains(ready.duration))
    }
}
