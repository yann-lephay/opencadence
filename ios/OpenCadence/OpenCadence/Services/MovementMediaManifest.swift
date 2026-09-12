import CadenceEngine
import Foundation

enum MovementMediaStatus: String, Codable {
    case awaitingBranding
    // User accepted for local integration, not professional/publication approval.
    case reviewedPreview
    case ready
}

enum MovementMediaPlayback: String {
    case loop, singlePass, hold
}

struct MovementMediaAsset: Equatable, Identifiable {
    let id: String
    let canonicalAngle: String
    let videoFilename: String
    let posterFilename: String
    let fallbackFilename: String
    let accessibilitySummary: String
    let status: MovementMediaStatus
    let playback: MovementMediaPlayback
}

enum MovementMediaManifest {
    static let all: [MovementMediaAsset] = movementIDs.map { movementID in
        MovementMediaAsset(
            id: movementID,
            canonicalAngle: canonicalAngle(for: movementID),
            videoFilename: "\(movementID)_main_v01.mp4",
            posterFilename: "\(movementID)_poster_v01.webp",
            fallbackFilename: "\(movementID)_phases_v01.webp",
            accessibilitySummary: String.localizedStringWithFormat(
                playback(for: movementID) == .hold
                    ? String(localized: "Démonstration de %@. Position à tenir ; consulte les consignes du mouvement.")
                    : String(localized: "Démonstration de %@. Suite de positions illustrant le mouvement, pas un rythme à suivre."),
                PresentationCopy.movementTitle(movementID)
            ),
            status: V2EngineConfiguration.approvedMovementIDs.contains(movementID) ? .ready : .reviewedPreview,
            playback: playback(for: movementID)
        )
    }

    static func asset(for exerciseID: String) -> MovementMediaAsset? {
        let movementID = V2EngineConfiguration.productPreview.catalog[exerciseID]?.resolvedMovementId
            ?? exerciseID
        return all.first { $0.id == movementID }
    }

    static var releaseIsComplete: Bool {
        all.allSatisfy { asset in
            asset.status == .ready
                && Bundle.main.url(forResource: resourceStem(asset.videoFilename), withExtension: "mp4") != nil
                && Bundle.main.url(forResource: resourceStem(asset.posterFilename), withExtension: "webp") != nil
                && Bundle.main.url(forResource: resourceStem(asset.fallbackFilename), withExtension: "webp") != nil
                && !asset.accessibilitySummary.isEmpty
        }
    }

    static func resourceURL(_ filename: String, bundle: Bundle = .main) -> URL? {
        let file = URL(fileURLWithPath: filename)
        return bundle.url(forResource: resourceStem(filename), withExtension: file.pathExtension)
    }

    private static func playback(for movementID: String) -> MovementMediaPlayback {
        switch movementID {
        case "front_plank", "side_plank", "elevated_front_plank": .hold
        case "eccentric_pull_up": .singlePass
        default: .loop
        }
    }

    private static let movementIDs = Array(
        Set(V2EngineConfiguration.productPreview.catalog.values.map(\.resolvedMovementId))
    ).sorted()

    private static func resourceStem(_ filename: String) -> String {
        URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    }

    private static func canonicalAngle(for movementID: String) -> String {
        switch movementID {
        case "single_arm_dumbbell_floor_press":
            return "depuis-les-pieds-surélevé"
        case "supported_calf_raise", "supported_single_leg_calf_raise":
            return "trois-quarts-arrière"
        case "wall_hip_hinge", "dumbbell_romanian_deadlift", "kettlebell_deadlift",
             "band_good_morning", "dumbbell_hip_thrust", "glute_bridge",
             "incline_push_up", "push_up", "front_plank", "elevated_front_plank":
            return "profil"
        case "side_plank", "supported_one_arm_row",
             "single_arm_overhead_press", "split_squat", "assisted_split_squat",
             "reverse_lunge", "low_step_up", "kickstand_romanian_deadlift",
             "suitcase_carry", "suitcase_march", "dip_bar_inverted_row":
            return "trois-quarts"
        default:
            return "face-trois-quarts"
        }
    }
}
