import AVFoundation
import Combine
import SwiftUI

struct MovementDemonstrationView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let exerciseID: String
    var showsPlaybackControls = true
    @StateObject private var playback = MovementVideoPlayback()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var reduceMotion: Bool {
        #if DEBUG
        systemReduceMotion || ProcessInfo.processInfo.arguments.contains("-OpenCadenceMediaReduceMotion")
        #else
        systemReduceMotion
        #endif
    }

    var body: some View {
        if let asset = MovementMediaManifest.asset(for: exerciseID) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    LBSBrand.cream
                    staticContent(asset)
                    if asset.playback != .hold, !playback.failed {
                        MovementPlayerLayer(player: playback.player)
                            .opacity(playback.hasStarted ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(asset.accessibilitySummary)
                if showsPlaybackControls, asset.playback != .hold, playback.available, !playback.failed {
                    Button { playback.toggle() } label: {
                        Image(systemName: playback.isPlaying ? "pause.fill" : playback.finished ? "arrow.counterclockwise" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(LBSBrand.controlTint)
                    .background(.regularMaterial, in: Circle())
                    .accessibilityLabel(playback.isPlaying ? String(localized: "Pause") : playback.finished ? String(localized: "Rejouer") : String(localized: "Lire une démonstration"))
                    .padding(8)
                }
            }
            .task(id: "\(asset.id)-\(reduceMotion)-\(lowPower)") {
                playback.prepare(
                    url: asset.status == .awaitingBranding || asset.playback == .hold ? nil : MovementMediaManifest.resourceURL(asset.videoFilename),
                    loops: MovementMediaPresentation.shouldLoop(kind: asset.playback, reduceMotion: reduceMotion, lowPower: lowPower),
                    autoplay: !reduceMotion && !screenshotUsesPoster
                )
                if scenePhase != .active { playback.suspend() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { playback.resumeAfterBackground() }
                else { playback.suspend() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .onDisappear { playback.stop() }
        }
    }

    @ViewBuilder
    private func staticContent(_ asset: MovementMediaAsset) -> some View {
        let fallback = image(asset.fallbackFilename)
        let poster = image(asset.posterFilename)
        let presentation = MovementMediaPresentation.select(
            status: asset.status, reduceMotion: reduceMotion,
            playbackRequested: playback.hasStarted,
            videoAvailable: !playback.failed && MovementMediaManifest.resourceURL(asset.videoFilename) != nil,
            fallbackAvailable: fallback != nil, posterAvailable: poster != nil
        )
        if presentation == .placeholder {
            VStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 42))
                Text("Démonstration en préparation").font(.headline)
            }.foregroundStyle(LBSBrand.controlTint)
        } else if let still = presentation == .fallback ? fallback ?? poster : poster ?? fallback {
            Image(uiImage: still).resizable().scaledToFit()
        }
    }

    private func image(_ filename: String) -> UIImage? {
        guard let url = MovementMediaManifest.resourceURL(filename) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private var screenshotUsesPoster: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-OpenCadenceScreenshotState")
            && !ProcessInfo.processInfo.arguments.contains("-OpenCadenceMediaAutoplay")
        #else
        false
        #endif
    }
}

enum MovementMediaPresentation: Equatable {
    case video, fallback, poster, placeholder

    static func select(status: MovementMediaStatus, reduceMotion: Bool, playbackRequested: Bool,
                       videoAvailable: Bool, fallbackAvailable: Bool, posterAvailable: Bool) -> Self {
        guard status != .awaitingBranding else { return .placeholder }
        if reduceMotion, !playbackRequested {
            if fallbackAvailable { return .fallback }
            if posterAvailable { return .poster }
            return .placeholder
        }
        if videoAvailable { return .video }
        if fallbackAvailable { return .fallback }
        if posterAvailable { return .poster }
        return .placeholder
    }

    static func shouldLoop(kind: MovementMediaPlayback, reduceMotion: Bool, lowPower: Bool) -> Bool {
        kind == .loop && !reduceMotion && !lowPower
    }
}

@MainActor
final class MovementVideoPlayback: ObservableObject {
    let player = AVQueuePlayer()
    @Published private(set) var available = false
    @Published private(set) var hasStarted = false
    @Published private(set) var isPlaying = false
    @Published private(set) var finished = false
    @Published private(set) var failed = false
    private var looper: AVPlayerLooper?
    private var currentItemObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var resumeOnActive = false
    private var generation = UUID()
    private var preparedURL: URL?

    func prepare(url: URL?, loops: Bool, autoplay: Bool) {
        // A policy change must not undo an explicit pause or replay choice.
        let shouldAutoplay = autoplay && !(available && preparedURL == url && !isPlaying && !resumeOnActive)
        stop()
        hasStarted = false
        failed = false
        finished = false
        guard let url else { return }
        preparedURL = url
        available = true
        player.isMuted = true
        player.actionAtItemEnd = loops ? .advance : .pause
        let token = generation
        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            let item = player.currentItem
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.statusObservation = item?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                    let isFailure = item.status == .failed
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token, isFailure else { return }
                        self.fail()
                    }
                }
            }
        }
        let item = AVPlayerItem(url: url)
        if loops { looper = AVPlayerLooper(player: player, templateItem: item) }
        else { player.insert(item, after: nil) }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: loops ? nil : item, queue: .main) { [weak self] _ in
            guard !loops else { return }
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.isPlaying = false
                self.finished = true
                self.hasStarted = false
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            guard let failedItem = note.object as? AVPlayerItem else { return }
            Task { @MainActor [weak self] in
                guard let self, self.generation == token, self.player.currentItem === failedItem else { return }
                self.fail()
            }
        }
        if shouldAutoplay { play() }
    }

    func toggle() {
        guard available, !failed else { return }
        if isPlaying { player.pause(); isPlaying = false }
        else if finished {
            let token = generation
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.finished = false
                    self.play()
                }
            }
        } else { play() }
    }

    private func play() {
        hasStarted = true
        isPlaying = true
        player.play()
    }

    func suspend() {
        // inactive -> background can arrive twice; preserve the first intent.
        resumeOnActive = resumeOnActive || isPlaying
        player.pause()
        isPlaying = false
    }

    func resumeAfterBackground() {
        if resumeOnActive, available, !failed, !finished { play() }
        resumeOnActive = false
    }

    private func fail() {
        failed = true
        isPlaying = false
        player.pause()
    }

    func stop() {
        generation = UUID()
        player.pause()
        looper = nil
        currentItemObservation = nil
        statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        endObserver = nil
        failureObserver = nil
        player.removeAllItems()
        available = false
        preparedURL = nil
        isPlaying = false
        resumeOnActive = false
    }
}

private struct MovementPlayerLayer: UIViewRepresentable {
    let player: AVQueuePlayer
    func makeUIView(context: Context) -> PlayerContainerView { PlayerContainerView() }
    func updateUIView(_ view: PlayerContainerView, context: Context) { view.playerLayer.player = player }
    static func dismantleUIView(_ view: PlayerContainerView, coordinator: ()) { view.playerLayer.player = nil }
}

private final class PlayerContainerView: UIView {
    private var readyObservation: NSKeyValueObservation?
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspect
        playerLayer.opacity = 0
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            let ready = layer.isReadyForDisplay
            Task { @MainActor [weak self] in self?.playerLayer.opacity = ready ? 1 : 0 }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
