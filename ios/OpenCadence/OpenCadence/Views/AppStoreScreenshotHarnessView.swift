#if DEBUG
import CadenceEngine
import SwiftData
import SwiftUI

enum AppStoreScreenshotState: String {
    case today
    case exercise
    case summary
    case media
    case welcome
    case settings
    case method
    case equipment
    case rest
    case journey
    case journeyPersistent
    case purchase
    case purchaseSuccess

    static var launchArgumentValue: AppStoreScreenshotState? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-OpenCadenceScreenshotState"),
              arguments.indices.contains(index + 1) else { return nil }
        return AppStoreScreenshotState(rawValue: arguments[index + 1])
    }
}

@MainActor
struct AppStoreScreenshotHarnessView: View {
    @StateObject private var subscriptions = SubscriptionStore()

    let state: AppStoreScreenshotState

    private let container: ModelContainer?
    private let setup: UserSetupRecord?
    private let activeRecord: ActiveWorkoutRecord?
    private let initializationError: String?

    init(state: AppStoreScreenshotState) {
        self.state = state

        do {
            let schema = Schema([
                UserSetupRecord.self,
                ActiveWorkoutRecord.self,
                CompletedWorkoutRecord.self,
            ])
            let configuration = state == .journeyPersistent
                ? ModelConfiguration(schema: schema, url: FileManager.default.temporaryDirectory.appendingPathComponent("lbs-handoff-flow-v2.store"))
                : ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            if state == .journeyPersistent {
                if try context.fetchCount(FetchDescriptor<UserSetupRecord>()) == 0 {
                    let setup = try UserSetupRecord(
                        inventory: Self.sampleInventory,
                        upperCalibration: "established", lowerCalibration: "established", calibrationCompletedAt: .now,
                        supportProfile: Self.sampleSupportProfile
                    )
                    context.insert(setup)
                    let prepared = Self.generatedWorkout
                    let snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context, now: .now)
                    context.insert(try ActiveWorkoutRecord(snapshot: snapshot))
                    try context.save()
                }
                let persistedSetup = try context.fetch(FetchDescriptor<UserSetupRecord>()).first
                self.container = container
                self.setup = persistedSetup
                self.activeRecord = nil
                self.initializationError = nil
                return
            }
            let inventory = Self.sampleInventory
            let supportProfile = Self.sampleSupportProfile
            let setup = try UserSetupRecord(
                inventory: inventory,
                selectedDuration: 30,
                upperCalibration: "established",
                lowerCalibration: "established",
                calibrationCompletedAt: Self.referenceDate,
                supportProfile: supportProfile
            )
            context.insert(setup)

            let activeRecord: ActiveWorkoutRecord?
            if [.today, .media, .welcome, .settings, .method, .equipment, .purchase, .purchaseSuccess].contains(state) {
                activeRecord = nil
            } else {
                let prepared = [.journey, .rest, .summary].contains(state) ? Self.generatedWorkout : Self.samplePreparedWorkout
                var snapshot = ActiveSessionCoordinator.start(
                    decision: prepared.decision,
                    v2Context: prepared.v2Context,
                    now: [.journey, .rest].contains(state) ? .now : Self.referenceDate
                )
                snapshot = Self.snapshot(snapshot, for: state, inventory: inventory)
                let record = try ActiveWorkoutRecord(snapshot: snapshot, now: Self.referenceDate)
                context.insert(record)
                activeRecord = record
            }

            try context.save()
            self.container = container
            self.setup = setup
            self.activeRecord = activeRecord
            initializationError = nil
        } catch {
            container = nil
            setup = nil
            activeRecord = nil
            initializationError = error.localizedDescription
        }
    }

    var body: some View {
        Group {
            if let container, let setup {
                Group {
                    if state == .journey || state == .journeyPersistent {
                        AppRootView()
                    } else {
                        NavigationStack {
                    switch state {
                    case .purchase:
                        PurchaseDesignPaywallView(product: nil, onPurchase: { _ in }, onRestore: {})
                    case .purchaseSuccess:
                        PurchaseDesignSuccessView(onStart: {})
                    case .welcome:
                        WelcomeView(setup: setup, hasActiveWorkout: false) {}
                    case .settings:
                        SettingsView(setup: setup)
                    case .method:
                        MethodView()
                    case .equipment:
                        EquipmentOnboardingView()
                    case .today:
                        HomeView(setup: setup)
                    case .media:
                        let arguments = ProcessInfo.processInfo.arguments
                        let index = arguments.firstIndex(of: "-OpenCadenceMediaID")
                        let id = index.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? "goblet_squat"
                        VStack(spacing: 20) {
                            Text(PresentationCopy.movementTitle(id)).font(.title2)
                            MovementDemonstrationView(exerciseID: id)
                                .frame(maxWidth: 440)
                            Spacer()
                        }
                        .padding()
                        .background(LBSBrand.cream)
                    case .journey, .journeyPersistent:
                        EmptyView()
                    case .exercise, .summary, .rest:
                        if let activeRecord {
                            ActiveWorkoutView(record: activeRecord)
                        } else {
                            unavailableView
                        }
                    }
                }
                    }
                }
                .modelContainer(container)
                .environmentObject(subscriptions)
                .tint(LBSBrand.controlTint)
            } else {
                unavailableView
            }
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label("Capture indisponible", systemImage: "camera.badge.ellipsis")
        } description: {
            Text(initializationError ?? String(localized: "La capture de référence n’a pas pu être préparée."))
        }
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_788_427_200)

    private static let sampleInventory = [
        EquipmentItem(
            category: "bodyweight",
            units: 1,
            supportedConfigurations: ["bodyweight"]
        ),
        EquipmentItem(
            category: "adjustable_dumbbell",
            units: 2,
            perUnitWeightsKg: [4, 6, 8, 10],
            supportedConfigurations: ["pair", "single", "central", "unilateral"]
        ),
    ]

    private static let sampleSupportProfile = UserSupportProfile(
        floorAllowed: true,
        stableSeatOrBench: true,
        solidWall: true,
        overheadClearance: true,
        travelSpace: true,
        bandFootSetupAllowed: false,
        pullupClearance: false,
        pullupTopStartSupport: false,
        bandOnPullupBarAllowed: false,
        dipBarsRowSafe: false,
        floorGripSafe: true,
        stepUpApprovedSupport: false,
        hipThrustBenchApproved: true
    )

    private static var generatedWorkout: PreparedWorkout {
        WorkoutEngineBridge.prepareWorkout(
            inventory: sampleInventory,
            durationMinutes: 30,
            engineVersion: .previewV2,
            todaySupports: sampleSupportProfile.engineSupportKeys,
            declaredScope: nil,
            now: .now
        )
    }

    private static var samplePreparedWorkout: PreparedWorkout {
        let engineConfiguration = V2EngineConfiguration.productPreview
        let items = [
            V2PlanItem(
                exerciseId: "goblet_squat",
                sets: 3,
                targetReps: 8,
                restSeconds: 75,
                load: V2Load(mode: .centralTotalKg, kg: 8),
                referenceStatus: "kept",
                progressionContext: "goblet_squat|adjustable_dumbbell|central_total_kg"
            ),
            V2PlanItem(
                exerciseId: "dumbbell_floor_press",
                sets: 3,
                targetReps: 8,
                restSeconds: 75,
                load: V2Load(mode: .pairEachKg, kg: 6),
                referenceStatus: "kept",
                progressionContext: "dumbbell_floor_press|adjustable_dumbbell|pair_each_kg"
            ),
            V2PlanItem(
                exerciseId: "supported_one_arm_row",
                sets: 2,
                targetReps: 8,
                restSeconds: 75,
                load: V2Load(mode: .singleTotalKg, kg: 8),
                referenceStatus: "kept",
                progressionContext: "supported_one_arm_row|adjustable_dumbbell|single_total_kg"
            ),
            V2PlanItem(
                exerciseId: "dumbbell_romanian_deadlift",
                sets: 2,
                targetReps: 8,
                restSeconds: 75,
                load: V2Load(mode: .pairEachKg, kg: 8),
                referenceStatus: "kept",
                progressionContext: "dumbbell_romanian_deadlift|adjustable_dumbbell|pair_each_kg"
            ),
            V2PlanItem(
                exerciseId: "dead_bug",
                sets: 2,
                targetReps: 8,
                restSeconds: 60,
                referenceStatus: "kept",
                progressionContext: "dead_bug|bodyweight"
            ),
        ]
        let movements = [
            movement("goblet_squat", pattern: "knee", sets: 3, target: 8, rest: 75, equipment: .init(category: "adjustable_dumbbell", configuration: "central")),
            movement("dumbbell_floor_press", pattern: "push", sets: 3, target: 8, rest: 75, equipment: .init(category: "adjustable_dumbbell", configuration: "pair")),
            movement("supported_one_arm_row", pattern: "pull", sets: 2, target: 8, rest: 75, equipment: .init(category: "adjustable_dumbbell", configuration: "unilateral")),
            movement("dumbbell_romanian_deadlift", pattern: "hinge", sets: 2, target: 8, rest: 75, equipment: .init(category: "adjustable_dumbbell", configuration: "pair")),
            PrescribedMovement(
                exerciseKey: "dead_bug",
                variant: "foundation",
                pattern: "core",
                sets: 2,
                target: repetitions(8),
                restSeconds: 60,
                equipment: [.init(category: "bodyweight", configuration: "bodyweight")]
            ),
        ]
        var decision = EngineDecision(
            decision: "generate_workout",
            reasonCodes: ["app_store.screenshot_fixture"]
        )
        decision.planProfileId = "app-store-screenshot-v1"
        decision.plan = movements.map { PlanRow(exerciseKey: $0.exerciseKey, sets: $0.sets) }
        decision.movements = movements
        let context = ActiveWorkoutV2Context(
            catalogVersion: engineConfiguration.catalogVersion,
            decisionPolicyVersion: engineConfiguration.decisionPolicyVersion,
            mode: .normal,
            durationMinutes: 30,
            estimatedSeconds: 29 * 60,
            plan: items,
            inventory: [
                V2InventoryItem(category: "bodyweight", units: 1),
                V2InventoryItem(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8, 10]),
            ],
            supports: sampleSupportProfile.engineSupportKeys
        )
        return PreparedWorkout(decision: decision, v2Context: context)
    }

    private static func movement(
        _ exerciseKey: String,
        pattern: String,
        sets: Int,
        target: Int,
        rest: Int,
        equipment: EquipmentRequirement
    ) -> PrescribedMovement {
        PrescribedMovement(
            exerciseKey: exerciseKey,
            variant: "established",
            pattern: pattern,
            sets: sets,
            target: repetitions(target),
            restSeconds: rest,
            equipment: [equipment]
        )
    }

    private static func repetitions(_ value: Int) -> String {
        String.localizedStringWithFormat(String(localized: "%lld répétitions"), value)
    }

    private static func snapshot(
        _ initial: ActiveWorkoutSnapshot,
        for state: AppStoreScreenshotState,
        inventory: [EquipmentItem]
    ) -> ActiveWorkoutSnapshot {
        guard state != .today else { return initial }
        if state == .journey { return initial }
        if state == .rest {
            let loaded = confirmCurrentLoad(in: initial, inventory: inventory)
            return ActiveSessionCoordinator.recordSet(loaded, repetitions: 8, now: .now)
        }
        if state == .exercise {
            return confirmCurrentLoad(in: initial, inventory: inventory)
        }

        var completed = initial
        var now = referenceDate
        for _ in 0..<100 {
            if completed.isFinished { break }
            completed = confirmCurrentLoad(in: completed, inventory: inventory)
            let reps = completed.v2Context?.plan.first { $0.exerciseId == completed.currentMovement?.exerciseKey }?.targetReps ?? 8
            now = now.addingTimeInterval(30)
            completed = ActiveSessionCoordinator.recordSet(completed, repetitions: reps, now: now)
            if !completed.isFinished {
                now = now.addingTimeInterval(Double(completed.originalRestSeconds ?? 0))
                completed = ActiveSessionCoordinator.completeRest(completed, now: now)
            }
        }
        return completed
    }

    private static func confirmCurrentLoad(
        in initial: ActiveWorkoutSnapshot,
        inventory: [EquipmentItem]
    ) -> ActiveWorkoutSnapshot {
        guard let movement = initial.currentMovement,
              let item = initial.v2Context?.plan.first(where: { $0.exerciseId == movement.exerciseKey })
        else { return initial }

        var result = initial
        if let weight = item.load?.kg {
            result = ActiveSessionCoordinator.confirmLoad(
                result,
                exerciseKey: movement.exerciseKey,
                perUnitWeightKg: weight,
                inventory: inventory
            )
        }
        if let optionID = item.load?.optionID {
            result = ActiveSessionCoordinator.confirmLoadOption(
                result,
                exerciseKey: movement.exerciseKey,
                optionID: optionID,
                inventory: inventory
            )
        }
        return result
    }
}
#endif
