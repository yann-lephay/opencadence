import Foundation
import Testing
import CadenceEngine

struct V2FixtureParityTests {
    @Test("Les 13 décisions V2 correspondent exactement aux fixtures")
    func allV2Fixtures() throws {
        let manifest = try loadManifest()
        let configuration = configuration(from: manifest)

        for fixture in manifest.cases {
            let request = try makeRequest(fixture)
            let first = CadenceEngine.decideV2(request: request, configuration: configuration)
            let second = CadenceEngine.decideV2(request: request, configuration: configuration)
            let expected = try makeExpectedResult(fixture)

            #expect(first == second, Comment(rawValue: "\(fixture.id): sortie non déterministe"))
            #expect(first == expected, Comment(rawValue: fixture.id))
        }
    }

    @Test("La configuration runtime preview reste identique au manifeste")
    func runtimePreviewMatchesFixtureManifest() throws {
        let manifest = try loadManifest()
        #expect(V2EngineConfiguration.referencePreview == configuration(from: manifest))
    }

    @Test("Une référence ne réintroduit jamais un palier absent")
    func unavailableReferenceLoadUsesCompatibleInventoryOnly() throws {
        let manifest = try loadManifest()
        let configuration = configuration(from: manifest)
        let context = try #require(manifest.catalog["floor_press"]?.progressionContext)
        let input = V2SessionDecisionInput(
            request: V2SessionRequest(durationMinutes: 20),
            todayInventory: [
                V2InventoryItem(category: "adjustable_dumbbell", units: 1, perUnitWeightsKg: [8]),
                V2InventoryItem(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [6, 10])
            ],
            todaySupports: ["floor_allowed"],
            history: [
                V2HistoryEntry(
                    endedAt: "2026-09-01T08:00:00.000Z",
                    completedExerciseIds: ["floor_press"],
                    references: [V2Reference(exerciseId: "floor_press", loadKg: 8, targetReps: 10, progressionContext: context)],
                    catalogVersion: manifest.catalogVersion,
                    decisionPolicyVersion: manifest.decisionPolicyVersion
                )
            ]
        )

        let result = CadenceEngine.decideV2(
            request: .sessionDecision(input, now: try #require(Self.date("2026-09-02T08:00:00.000Z"))),
            configuration: configuration
        )
        guard case let .sessionDecision(decision) = result else {
            Issue.record("Une décision de séance était attendue")
            return
        }
        let floorPress = try #require(decision.plan.first { $0.exerciseId == "floor_press" })
        #expect(floorPress.load?.kg == 6)
        #expect(floorPress.referenceStatus == "recalibrating")
    }

    @Test("Une reprise ne reconstruit que le travail non commencé")
    func activeResumeDoesNotAddCompletedAnchors() throws {
        let manifest = try loadManifest()
        let configuration = configuration(from: manifest)
        let floorContext = try #require(manifest.catalog["floor_press"]?.progressionContext)
        let rowContext = try #require(manifest.catalog["one_arm_row"]?.progressionContext)
        let input = V2SessionDecisionInput(
            request: V2SessionRequest(durationMinutes: 20, remainingSeconds: 720),
            todayInventory: [V2InventoryItem(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [6, 8, 10])],
            todaySupports: ["floor_allowed", "stable_hand_support", "wall_or_stable_plane"],
            activeSession: V2ActiveSession(
                sessionId: "strict-resume",
                mode: .normal,
                catalogVersion: manifest.catalogVersion,
                decisionPolicyVersion: manifest.decisionPolicyVersion,
                confirmed: [V2ConfirmedWork(exerciseId: "one_arm_row", sets: 3, targetReps: 8, load: V2Load(mode: .singleTotalKg, kg: 6), progressionContext: rowContext)],
                unstarted: [V2UnstartedWork(exerciseId: "floor_press", sets: 3, targetReps: 10, restSeconds: 90, load: V2Load(mode: .pairEachKg, kg: 8), referenceStatus: "kept", progressionContext: floorContext)]
            )
        )

        let result = CadenceEngine.decideV2(
            request: .sessionDecision(input, now: try #require(Self.date("2026-09-02T08:00:00.000Z"))),
            configuration: configuration
        )
        guard case let .sessionDecision(decision) = result else {
            Issue.record("Une décision de séance était attendue")
            return
        }
        #expect(decision.plan.map(\.exerciseId) == ["floor_press"])
        #expect(decision.confirmed == input.activeSession?.confirmed)
    }

    @Test("Finir à l'heure conserve la prescription et retire seulement des séries")
    func finishOnTimePreservesPlannedDimensions() throws {
        let manifest = try loadManifest()
        let configuration = configuration(from: manifest)
        let context = try #require(manifest.catalog["floor_press"]?.progressionContext)
        let input = V2ActiveTransitionInput(
            action: .finishOnTime,
            catalogVersion: manifest.catalogVersion,
            decisionPolicyVersion: manifest.decisionPolicyVersion,
            remainingSeconds: 270,
            unstarted: [
                V2UnstartedWork(
                    exerciseId: "floor_press",
                    sets: 4,
                    targetReps: 11,
                    restSeconds: 90,
                    load: V2Load(mode: .pairEachKg, kg: 8),
                    referenceStatus: "kept",
                    progressionContext: context
                )
            ]
        )

        let result = CadenceEngine.decideV2(request: .activeSessionTransition(input), configuration: configuration)
        guard case let .activeSessionTransition(decision) = result else {
            Issue.record("Une transition de séance active était attendue")
            return
        }
        let remaining = try #require(decision.plan.first)
        #expect(remaining.sets == 2)
        #expect(remaining.targetReps == 11)
        #expect(remaining.restSeconds == 90)
        #expect(remaining.load == V2Load(mode: .pairEachKg, kg: 8))
        #expect(remaining.referenceStatus == "kept")
        #expect(remaining.progressionContext == context)
        #expect(decision.removed == [V2RemovedWork(exerciseId: "floor_press", sets: 2, progressionContext: context)])
    }

    @Test("Une prescription d'une autre version ne progresse pas")
    func incompatiblePrescriptionVersionIsHeld() throws {
        let manifest = try loadManifest()
        let configuration = configuration(from: manifest)
        let context = try #require(manifest.catalog["floor_press"]?.progressionContext)
        let previous = V2Prescription(
            exerciseId: "floor_press",
            sets: 3,
            targetReps: 12,
            load: V2Load(mode: .pairEachKg, kg: 8),
            progressionContext: context,
            catalogVersion: "fixture-v1",
            decisionPolicyVersion: manifest.decisionPolicyVersion
        )
        let input = V2ProgressionInput(
            todayInventory: [V2InventoryItem(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [8, 10])],
            previousPrescription: previous,
            exposures: [
                V2Exposure(
                    confirmedReps: [12, 12, 12],
                    loadKg: 8,
                    allPrescribedSetsConfirmed: true,
                    progressionContext: context,
                    catalogVersion: manifest.catalogVersion,
                    decisionPolicyVersion: manifest.decisionPolicyVersion
                )
            ],
            todaySupports: ["floor_allowed"]
        )

        let result = CadenceEngine.decideV2(request: .progressionTransition(input), configuration: configuration)
        guard case let .progressionTransition(decision) = result else {
            Issue.record("Une transition de progression était attendue")
            return
        }
        #expect(decision.decision == .holdPrescription)
        #expect(decision.nextPrescription.exerciseId == previous.exerciseId)
        #expect(decision.nextPrescription.sets == previous.sets)
        #expect(decision.nextPrescription.targetReps == previous.targetReps)
        #expect(decision.nextPrescription.load == previous.load)
        #expect(decision.nextPrescription.progressionContext == previous.progressionContext)
        #expect(decision.changedFields.isEmpty)
    }

    @Test("Une séance active d'une autre version n'est jamais réinterprétée")
    func incompatibleActiveSessionVersionIsRejected() throws {
        let manifest = try loadManifest()
        let configuration = configuration(from: manifest)
        let context = try #require(manifest.catalog["bodyweight_squat"]?.progressionContext)
        let work = V2UnstartedWork(
            exerciseId: "bodyweight_squat",
            sets: 2,
            targetReps: 8,
            restSeconds: 75,
            referenceStatus: "kept",
            progressionContext: context
        )
        let active = V2ActiveSession(
            sessionId: "old-active",
            mode: .normal,
            catalogVersion: "fixture-v1",
            decisionPolicyVersion: manifest.decisionPolicyVersion,
            confirmed: [],
            unstarted: [work]
        )
        let sessionInput = V2SessionDecisionInput(
            request: V2SessionRequest(durationMinutes: 20, remainingSeconds: 300),
            activeSession: active
        )

        let sessionResult = CadenceEngine.decideV2(
            request: .sessionDecision(sessionInput, now: try #require(Self.date("2026-09-02T08:00:00.000Z"))),
            configuration: configuration
        )
        guard case let .sessionDecision(sessionDecision) = sessionResult else {
            Issue.record("Une décision de séance était attendue")
            return
        }
        #expect(sessionDecision.decision == .requestValidInput)
        #expect(sessionDecision.plan.isEmpty)

        let transitionResult = CadenceEngine.decideV2(
            request: .activeSessionTransition(V2ActiveTransitionInput(
                action: .finishOnTime,
                catalogVersion: "fixture-v1",
                decisionPolicyVersion: manifest.decisionPolicyVersion,
                remainingSeconds: 300,
                unstarted: [work]
            )),
            configuration: configuration
        )
        guard case let .activeSessionTransition(transitionDecision) = transitionResult else {
            Issue.record("Une transition de séance active était attendue")
            return
        }
        #expect(transitionDecision.decision == .requestValidInput)
        #expect(transitionDecision.plan.isEmpty)
    }

    private func configuration(from manifest: V2FixtureManifest) -> V2EngineConfiguration {
        V2EngineConfiguration(
            catalogVersion: manifest.catalogVersion,
            decisionPolicyVersion: manifest.decisionPolicyVersion,
            catalog: manifest.catalog,
            substitutions: manifest.substitutions,
            policy: manifest.policy
        )
    }

    private func makeRequest(_ fixture: V2FixtureCase) throws -> V2EngineRequest {
        switch fixture.kind {
        case .sessionDecision:
            let request = try #require(fixture.input.request)
            let now = try #require(Self.date(fixture.now))
            return .sessionDecision(
                V2SessionDecisionInput(
                    request: request,
                    persistentInventory: fixture.input.persistentInventory ?? [],
                    todayInventory: fixture.input.todayInventory ?? [],
                    todaySupports: fixture.input.todaySupports ?? [],
                    history: fixture.input.history ?? [],
                    refusals: fixture.input.refusals ?? [],
                    activeSession: fixture.input.activeSession,
                    declaredCurrentHealthSignal: fixture.input.declaredCurrentHealthSignal ?? false,
                    declaredScope: fixture.input.declaredScope
                ),
                now: now
            )
        case .progressionTransition:
            return .progressionTransition(
                V2ProgressionInput(
                    todayInventory: fixture.input.todayInventory ?? [],
                    previousPrescription: try #require(fixture.input.previousPrescription),
                    exposures: fixture.input.exposures ?? [],
                    todaySupports: fixture.input.todaySupports ?? []
                )
            )
        case .activeSessionTransition:
            return .activeSessionTransition(
                V2ActiveTransitionInput(
                    action: try #require(fixture.input.action),
                    catalogVersion: try #require(fixture.input.catalogVersion),
                    decisionPolicyVersion: try #require(fixture.input.decisionPolicyVersion),
                    remainingSeconds: fixture.input.remainingSeconds,
                    activeExerciseId: fixture.input.activeExerciseId,
                    confirmed: fixture.input.confirmed ?? [],
                    unstarted: fixture.input.unstarted ?? []
                )
            )
        }
    }

    private func makeExpectedResult(_ fixture: V2FixtureCase) throws -> V2EngineResult {
        let expected = fixture.expected
        switch fixture.kind {
        case .sessionDecision:
            return .sessionDecision(
                V2SessionDecision(
                    catalogVersion: expected.catalogVersion,
                    decisionPolicyVersion: expected.decisionPolicyVersion,
                    decision: expected.decision,
                    sessionId: expected.sessionId,
                    mode: expected.mode ?? fixture.input.request?.mode ?? .normal,
                    estimatedSeconds: expected.estimatedSeconds ?? 0,
                    plan: expected.plan ?? [],
                    confirmed: expected.confirmed ?? [],
                    coveredAnchors: expected.coveredAnchors ?? [],
                    omittedAnchors: expected.omittedAnchors ?? [],
                    reasons: expected.reasons,
                    automaticProgression: expected.automaticProgression ?? false,
                    confirmedImmutable: expected.confirmedImmutable ?? false,
                    createsDebt: expected.createsDebt ?? false,
                    persistentInventoryChanged: expected.persistentInventoryChanged ?? false,
                    differentiatedClinicalOrientation: expected.differentiatedClinicalOrientation ?? false
                )
            )
        case .progressionTransition:
            return .progressionTransition(
                V2ProgressionDecision(
                    catalogVersion: expected.catalogVersion,
                    decisionPolicyVersion: expected.decisionPolicyVersion,
                    decision: expected.decision,
                    nextPrescription: try #require(expected.nextPrescription),
                    changedFields: expected.changedFields ?? [],
                    atomicChange: expected.atomicChange,
                    reasons: expected.reasons
                )
            )
        case .activeSessionTransition:
            return .activeSessionTransition(
                V2ActiveTransitionDecision(
                    catalogVersion: expected.catalogVersion,
                    decisionPolicyVersion: expected.decisionPolicyVersion,
                    decision: expected.decision,
                    confirmedImmutable: expected.confirmedImmutable ?? true,
                    createsDebt: expected.createsDebt ?? false,
                    estimatedSeconds: expected.estimatedSeconds ?? 0,
                    plan: expected.plan ?? [],
                    removed: expected.removed ?? [],
                    confirmed: expected.confirmed ?? [],
                    exposedActions: expected.exposedActions ?? [],
                    loadedAlternative: expected.loadedAlternative,
                    reasons: expected.reasons
                )
            )
        }
    }

    private func loadManifest() throws -> V2FixtureManifest {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let candidate = directory.appending(path: "fixtures/ios-engine-v2/cases.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try JSONDecoder().decode(V2FixtureManifest.self, from: Data(contentsOf: candidate))
            }
            directory.deleteLastPathComponent()
        }
        throw V2FixtureError.manifestNotFound
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

private enum V2FixtureError: Error {
    case manifestNotFound
}

private enum V2CaseKind: String, Decodable {
    case sessionDecision = "session_decision"
    case progressionTransition = "progression_transition"
    case activeSessionTransition = "active_session_transition"
}

private struct V2FixtureManifest: Decodable {
    let catalogVersion: String
    let decisionPolicyVersion: String
    let policy: V2DecisionPolicy
    let catalog: [String: V2ExerciseDefinition]
    let substitutions: [V2Substitution]
    let cases: [V2FixtureCase]
}

private struct V2FixtureCase: Decodable {
    let id: String
    let kind: V2CaseKind
    let now: String
    let input: V2FixtureInput
    let expected: V2FixtureExpected
}

private struct V2FixtureInput: Decodable {
    let request: V2SessionRequest?
    let persistentInventory: [V2InventoryItem]?
    let todayInventory: [V2InventoryItem]?
    let todaySupports: [String]?
    let history: [V2HistoryEntry]?
    let refusals: [V2Refusal]?
    let activeSession: V2ActiveSession?
    let declaredCurrentHealthSignal: Bool?
    let declaredScope: V2DeclaredScope?
    let previousPrescription: V2Prescription?
    let exposures: [V2Exposure]?
    let action: V2ActiveAction?
    let catalogVersion: String?
    let decisionPolicyVersion: String?
    let remainingSeconds: Int?
    let activeExerciseId: String?
    let confirmed: [V2ConfirmedWork]?
    let unstarted: [V2UnstartedWork]?
}

private struct V2FixtureExpected: Decodable {
    let catalogVersion: String
    let decisionPolicyVersion: String
    let decision: V2DecisionName
    let sessionId: String?
    let mode: V2SessionMode?
    let estimatedSeconds: Int?
    let plan: [V2PlanItem]?
    let confirmed: [V2ConfirmedWork]?
    let coveredAnchors: [String]?
    let omittedAnchors: [String]?
    let reasons: [V2Reason]
    let automaticProgression: Bool?
    let confirmedImmutable: Bool?
    let createsDebt: Bool?
    let persistentInventoryChanged: Bool?
    let differentiatedClinicalOrientation: Bool?
    let nextPrescription: V2Prescription?
    let changedFields: [String]?
    let atomicChange: String?
    let removed: [V2RemovedWork]?
    let exposedActions: [String]?
    let loadedAlternative: V2PlanItem?
}
