import AVFoundation
import Foundation

struct RestCountdownCue: Equatable {
    let secondsRemaining: Int
    let date: Date

    static func upcoming(until deadline: Date, now: Date) -> [Self] {
        guard deadline > now else { return [] }
        return [3, 2, 1, 0].compactMap { seconds in
            let date = deadline.addingTimeInterval(-Double(seconds))
            return date >= now ? Self(secondsRemaining: seconds, date: date) : nil
        }
    }

    func isTimely(at now: Date) -> Bool {
        // Never replay missed cues in a burst after a suspension or interruption.
        (0..<0.25).contains(now.timeIntervalSince(date))
    }
}

@MainActor
enum RestCountdownAudio {
    static func play(until deadline: Date) async {
        let cues = RestCountdownCue.upcoming(until: deadline, now: .now)
        guard !cues.isEmpty,
              let tickURL = Bundle.main.url(forResource: "rest-tick", withExtension: "wav"),
              let readyURL = Bundle.main.url(forResource: "rest-ready", withExtension: "wav") else { return }

        do {
            let tick = try AVAudioPlayer(contentsOf: tickURL)
            let ready = try AVAudioPlayer(contentsOf: readyURL)
            tick.prepareToPlay()
            ready.prepareToPlay()
            defer {
                tick.stop()
                ready.stop()
            }

            for cue in cues {
                let delay = cue.date.timeIntervalSinceNow
                if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                try Task.checkCancellation()
                guard cue.isTimely(at: .now) else { continue }
                // Respect silent mode and mix with the user's music.
                try AVAudioSession.sharedInstance().setCategory(.ambient)
                let player = cue.secondsRemaining == 0 ? ready : tick
                player.currentTime = 0
                player.play()
            }
            try await Task.sleep(for: .seconds(ready.duration))
        } catch {
            // Audio is supplementary: cancellation or unavailable audio must
            // never change the timer or the recorded workout.
        }
    }
}
