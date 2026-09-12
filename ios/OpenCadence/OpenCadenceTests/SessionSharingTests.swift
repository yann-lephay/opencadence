import Foundation
import SwiftData
import Testing
@testable import OpenCadence

private final class SharingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var code = 200
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) @MainActor
struct SessionSharingTests {
    func store(_ enrollment: SharingEnrollment? = nil, endpoint: URL? = URL(string:"https://collector.invalid")) -> SessionSharing {
        SharingProtocol.requests = []; SharingProtocol.code = 200
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SharingProtocol.self]
        return SessionSharing(endpoint: endpoint, transport: URLSession(configuration: config), load: { enrollment }, persist: { _ in })
    }
    func container() throws -> ModelContainer {
        let container = try ModelContainer(for: UserSetupRecord.self, ActiveWorkoutRecord.self, CompletedWorkoutRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly:true))
        return container
    }
    @Test func freeUnconfiguredAndPreConsentSessionsCannotEnroll() {
        let sharing = store()
        sharing.accept(paid:false); #expect(sharing.enrollment == nil)
        sharing.accept(paid:true)
        #expect(sharing.active)
        #expect(sharing.completionEnrollment(paid:false,startedAt:.now) == nil)
        #expect(sharing.completionEnrollment(paid:true,startedAt:.distantPast) == nil)
        #expect(sharing.completionEnrollment(paid:true,startedAt:nil) == nil)
        #expect(sharing.completionEnrollment(paid:true,startedAt:.now) != nil)
        let disabled = store(endpoint:nil); disabled.accept(paid:true); #expect(!disabled.active)
    }
    @Test func failureToSaveConsentNeverEnablesCollection() {
        let sharing = SessionSharing(endpoint:URL(string:"https://collector.invalid"),load:{nil},persist:{_ in throw URLError(.cannotWriteToFile)})
        sharing.accept(paid:true); #expect(!sharing.active)
    }
    @Test func stoppedEnrollmentRetainsDeletionUntilServerAcknowledgesEvenWithoutPurchase() async throws {
        let sharing = store(); sharing.accept(paid:true); sharing.stop()
        #expect(sharing.completionEnrollment(paid:true,startedAt:.now) == nil)
        let storeContainer = try container(); let ctx = storeContainer.mainContext
        SharingProtocol.code = 503
        await sharing.sync(records:[],context:ctx,paid:false)
        #expect(sharing.enrollment?.deleting == true)
        SharingProtocol.code = 200
        await sharing.sync(records:[],context:ctx,paid:false)
        #expect(sharing.enrollment == nil)
        #expect(SharingProtocol.requests.allSatisfy { $0.httpMethod == "DELETE" })
    }
    @Test func lossOfPaidAccessDoesNotUpload() async throws {
        let sharing = store(); sharing.accept(paid:true)
        let storeContainer = try container()
        await sharing.sync(records:[],context:storeContainer.mainContext,paid:false)
        #expect(SharingProtocol.requests.isEmpty)
    }
    @Test func uploadUsesEligibleConfirmedHistoryOnlyAndIsNotRepeated() async throws {
        let sharing = store(); sharing.accept(paid:true,now:.now.addingTimeInterval(-60))
        let prepared = PersonalizationNativeTests().prepared()
        var snapshot = ActiveSessionCoordinator.start(decision:prepared.decision,v2Context:prepared.v2Context,now:.now)
        snapshot = ActiveSessionCoordinator.startSet(snapshot,now:.now)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot,repetitions:6,now:.now)
        snapshot.feedback = .init(effort:9,discomfort:4,repetitionsInReserve:1)
        snapshot.endedEarly = true
        let payload = WorkoutHistoryBuilder.payload(from:snapshot)
        let eligible = try CompletedWorkoutRecord(payload:payload)
        eligible.sharingEnrollmentID = sharing.completionEnrollment(paid:true,startedAt:snapshot.startedAt)
        let old = try CompletedWorkoutRecord(payload:payload)
        let storeContainer = try container(); let ctx = storeContainer.mainContext; ctx.insert(eligible); ctx.insert(old); try ctx.save()
        await sharing.sync(records:[eligible,old],context:ctx,paid:true)
        #expect(eligible.sharedAt != nil); #expect(old.sharedAt == nil)
        #expect(SharingProtocol.requests.filter { $0.url!.path.contains("sessions/") }.count == 1)
        await sharing.sync(records:[eligible,old],context:ctx,paid:true)
        #expect(SharingProtocol.requests.filter { $0.url!.path.contains("sessions/") }.count == 1)
        let json = String(data:try JSONEncoder().encode(SharedSession(payload)),encoding:.utf8)!
        for forbidden in ["feedback","discomfort","pain","inventory","sessionID","completedAt","loadOptionID"] { #expect(!json.contains(forbidden)) }
        #expect(eligible.payload == payload)
    }
}

/// Opt-in integration test; synthetic memory-only journal, no user keychain.
@Suite @MainActor
struct SessionSharingHostedTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LBS_TEST_HOSTED_SHARING"] == "1"))
    func syntheticSessionUploadsAndDeletesOverHTTPS() async throws {
        let sharing = SessionSharing(endpoint: URL(string: "https://collecte.labonneseance.com"), load: { nil }, persist: { _ in })
        sharing.accept(paid: true, now: .now.addingTimeInterval(-60))
        let token = try #require(sharing.enrollment?.token)
        let prepared = PersonalizationNativeTests().prepared()
        var snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context, now: .now)
        snapshot = ActiveSessionCoordinator.startSet(snapshot, now: .now)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 6, now: .now)
        snapshot.endedEarly = true
        let record = try CompletedWorkoutRecord(payload: WorkoutHistoryBuilder.payload(from: snapshot))
        record.sharingEnrollmentID = sharing.completionEnrollment(paid: true, startedAt: snapshot.startedAt)
        record.sessionReviewData = try JSONEncoder().encode(SessionReview(impression: .mixed, reason: .repetitive))
        let container = try SessionSharingTests().container()
        container.mainContext.insert(record); try container.mainContext.save()
        await sharing.sync(records: [record], context: container.mainContext, paid: true)
        let uploaded = record.sharedAt != nil
        sharing.stop()
        await sharing.sync(records: [record], context: container.mainContext, paid: false)
        #expect(sharing.enrollment == nil)
        #expect(uploaded)
        var late = URLRequest(url: URL(string: "https://collecte.labonneseance.com/v1/consent")!)
        late.httpMethod = "PUT"
        late.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        late.setValue("application/json", forHTTPHeaderField: "Content-Type")
        late.httpBody = Data("{}".utf8)
        let (_, response) = try await SessionSharing.privateTransport().data(for: late)
        #expect((response as? HTTPURLResponse)?.statusCode == 410)
    }
}


@Suite @MainActor
struct SessionReviewTests {
    @Test func cadenceAndEligibility() {
        for index in 0..<10 {
            #expect(SessionReview.shouldAsk(paid: true, enrollmentID: "enrolled", priorEligibleCount: index, hasWork: true) == [0,3,6,9].contains(index))
        }
        #expect(!SessionReview.shouldAsk(paid: false, enrollmentID: "enrolled", priorEligibleCount: 0, hasWork: true))
        #expect(!SessionReview.shouldAsk(paid: true, enrollmentID: nil, priorEligibleCount: 0, hasWork: true))
        #expect(!SessionReview.shouldAsk(paid: true, enrollmentID: "enrolled", priorEligibleCount: 0, hasWork: false))
    }
    @Test func oldConsentCannotAuthorizeNewReports() {
        let old = SharingEnrollment(token: String(repeating: "a", count: 64), acceptedAt: .distantPast, version: "session-sharing-1")
        let sharing = SessionSharingTests().store(old)
        #expect(!sharing.active)
        #expect(sharing.completionEnrollment(paid: true, startedAt: .now) == nil)
    }
    @Test func completionSavesReviewOnceAndNeverAddsItWithoutEnrollment() throws {
        let prepared = PersonalizationNativeTests().prepared()
        let snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context, now: .now)
        let container = try SessionSharingTests().container()
        let ctx = container.mainContext
        let first = try ActiveWorkoutRecord(snapshot: snapshot); ctx.insert(first); try ctx.save()
        let review = SessionReview(impression: .mixed, reason: .repetitive)
        try WorkoutCompletionCoordinator.save(snapshot: snapshot, activeRecord: first, context: ctx, sharingEnrollmentID: "enrolled", sessionReview: review)
        let duplicate = try ActiveWorkoutRecord(snapshot: snapshot); ctx.insert(duplicate); try ctx.save()
        try WorkoutCompletionCoordinator.save(snapshot: snapshot, activeRecord: duplicate, context: ctx, sharingEnrollmentID: "enrolled", sessionReview: .init(impression: .fits))
        let saved = try ctx.fetch(FetchDescriptor<CompletedWorkoutRecord>())
        #expect(saved.count == 1 && saved.first?.sessionReview == review)
        let otherContainer = try SessionSharingTests().container()
        let unshared = try ActiveWorkoutRecord(snapshot: snapshot); otherContainer.mainContext.insert(unshared)
        try WorkoutCompletionCoordinator.save(snapshot: snapshot, activeRecord: unshared, context: otherContainer.mainContext, sessionReview: review)
        #expect(try otherContainer.mainContext.fetch(FetchDescriptor<CompletedWorkoutRecord>()).first?.sessionReview == nil)
    }
    @Test func reviewIsOptionalAndDoesNotChangeEnginePayload() throws {
        let prepared = PersonalizationNativeTests().prepared()
        let snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context, now: .now)
        let payload = WorkoutHistoryBuilder.payload(from: snapshot)
        let plain = try #require(SharedSession(payload))
        let review = SessionReview(impression: .mixed, reason: .repetitive)
        let withReview = try #require(SharedSession(payload, review: review))
        #expect(plain.review == nil)
        #expect(withReview.plan == plain.plan && withReview.work == plain.work)
        let record = try CompletedWorkoutRecord(payload: payload)
        record.sessionReviewData = try JSONEncoder().encode(review)
        #expect(record.sessionReview == review)
        #expect(record.payload == payload)
    }
}
