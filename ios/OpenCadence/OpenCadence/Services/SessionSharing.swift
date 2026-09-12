import Foundation
import CadenceEngine
import Combine
import CryptoKit
import Security
import SwiftData

/// Product feedback, separate from the health/effort feedback used by the engine.
struct SessionReview: Codable, Equatable {
    enum Impression: String, Codable, CaseIterable { case fits, mixed, notFit }
    enum Reason: String, Codable, CaseIterable { case tooEasy, tooHard, repetitive, unclear }
    var impression: Impression
    var reason: Reason?

    static func shouldAsk(paid: Bool, enrollmentID: String?, priorEligibleCount: Int, hasWork: Bool) -> Bool {
        paid && enrollmentID != nil && hasWork && priorEligibleCount >= 0 && priorEligibleCount % 3 == 0
    }
}

/// Explicit allowlist. Never encode a snapshot/profile into a network request.
struct SharedSession: Codable, Equatable {
    struct Plan: Codable, Equatable {
        let exercise: String
        let sets: Int
        let target: Int
        let unit: String
        let kg: Double?
        let rest: Int
    }
    struct Work: Codable, Equatable {
        let exercise: String
        let actual: Int
        let target: Int?
        let kg: Double?
        let rest: Int?
        let unit: String?
    }
    let version: Int
    let day: String
    let policy: String
    let catalog: String
    let endedEarly: Bool
    let plan: [Plan]
    let work: [Work]
    let review: SessionReview?

    init?(_ payload: CompletedWorkoutPayload, review: SessionReview? = nil) {
        self.review = review
        guard let context = payload.snapshot.v2Context else { return nil }
        version = 1
        day = String(ISO8601DateFormatter().string(from: payload.endedAt).prefix(10))
        policy = context.decisionPolicyVersion
        catalog = context.catalogVersion
        endedEarly = payload.snapshot.endedEarly
        plan = context.plan.map { .init(exercise: $0.exerciseId, sets: $0.sets,
            target: $0.targetReps, unit: $0.resolvedTargetUnit.rawValue, kg: $0.load?.kg, rest: $0.restSeconds) }
        work = payload.snapshot.recordedSets.map { work in .init(exercise: work.exerciseKey,
            actual: work.repetitions, target: work.prescribedRepetitions, kg: work.perUnitWeightKg, rest: work.actualRestSeconds,
            unit: context.plan.first(where: { $0.exerciseId == work.exerciseKey })?.resolvedTargetUnit.rawValue) }
    }
}

struct SharingEnrollment: Codable, Equatable {
    let token: String
    let acceptedAt: Date
    var deleting = false
    var version = "session-sharing-2"
}

@MainActor
final class SessionSharing: ObservableObject {
    static let shared = SessionSharing()
    static let consentVersion = "session-sharing-2"
    @Published private(set) var enrollment: SharingEnrollment?
    @Published private(set) var message: String?
    @Published private(set) var busy = false
    private let endpoint: URL?
    private let transport: URLSession
    private let persist: (SharingEnrollment?) throws -> Void
    private var storageAvailable = true

    var available: Bool { endpoint != nil && storageAvailable }
    var active: Bool { enrollment?.version == Self.consentVersion && enrollment?.deleting == false }

    init(endpoint: URL? = SessionSharing.configuredEndpoint,
         transport: URLSession = SessionSharing.privateTransport(),
         load: () throws -> SharingEnrollment? = SharingKeychain.load,
         persist: @escaping (SharingEnrollment?) throws -> Void = SharingKeychain.save) {
        self.endpoint = endpoint; self.transport = transport; self.persist = persist
        do { enrollment = try load() }
        catch { storageAvailable = false; message = String(localized: "Le réglage de partage est indisponible. Aucune donnée ne sera envoyée.") }
    }

    static var configuredEndpoint: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "LBSSessionSharingURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil else { return nil }
        return url
    }

    static func privateTransport() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.httpShouldSetCookies = false
        return URLSession(configuration: config, delegate: SharingNoRedirect(), delegateQueue: nil)
    }

    func accept(paid: Bool, now: Date = .now) {
        guard paid, available, enrollment == nil else { return }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return }
        let next = SharingEnrollment(token: bytes.map { String(format: "%02x", $0) }.joined(), acceptedAt: now)
        do { try persist(next); enrollment = next; message = String(localized: "Partage activé pour les prochaines séances.") }
        catch { message = String(localized: "Le choix n’a pas pu être enregistré. Le partage reste désactivé.") }
    }

    /// Called only on completion, never inferred later from a new purchase.
    func completionEnrollment(paid: Bool, startedAt: Date?) -> String? {
        guard paid, available, let current = enrollment, current.version == Self.consentVersion, !current.deleting,
              let startedAt, startedAt >= current.acceptedAt else { return nil }
        return Self.digest(current.token)
    }

    func stop() {
        guard var next = enrollment else { return }
        next.deleting = true
        // Stop in memory even if the local write fails. Do not claim durable success.
        enrollment = next
        do { try persist(next); message = String(localized: "Partage arrêté. Suppression à transmettre au serveur.") }
        catch { storageAvailable = false; message = String(localized: "Partage suspendu. Impossible d’enregistrer l’arrêt : réessaie avant de fermer l’app.") }
    }

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func sync(records: [CompletedWorkoutRecord], context: ModelContext, paid: Bool) async {
        guard !busy, let current = enrollment, endpoint != nil else { return }
        // Persist a previously failed stop before any more networking.
        if current.deleting {
            do { try persist(current); storageAvailable = true } catch { return }
        }
        guard storageAvailable, paid || current.deleting else { return }
        busy = true
        defer { busy = false }
        do {
            if !current.deleting {
                guard current.version == Self.consentVersion else { return }
                struct Consent: Encodable { let version: String; let acceptedAt: String }
                try await request("PUT", path: "consent", token: current.token,
                    body: JSONEncoder().encode(Consent(version: current.version,
                        acceptedAt: ISO8601DateFormatter().string(from: current.acceptedAt))))
                for record in records.sorted(by: { $0.endedAt < $1.endedAt }) {
                    guard enrollment == current else { break }
                    guard record.sharingEnrollmentID == Self.digest(current.token), record.sharedAt == nil,
                          record.endedAt > Date.now.addingTimeInterval(-89 * 86400),
                          let payload = record.payload, let report = SharedSession(payload, review: record.sessionReview) else { continue }
                    let id = Self.digest(current.token + record.sessionID)
                    try await request("PUT", path: "sessions/" + id, token: current.token,
                        body: JSONEncoder().encode(report))
                    guard enrollment == current else { break }
                    record.sharedAt = .now
                    do { try context.save() } catch { record.sharedAt = nil; throw error }
                }
                if enrollment == current { message = String(localized: "Les séances en attente ont été transmises.") }
            }
            // A stop during an upload is processed after that request, before returning.
            if let latest = enrollment, latest.deleting {
                try await request("DELETE", path: "consent", token: latest.token, body: nil)
                try persist(nil); enrollment = nil
                message = String(localized: "Les données partagées ont été supprimées. Ton historique sur cet iPhone est conservé.")
            }
        } catch {
            message = enrollment?.deleting == true
                ? String(localized: "Partage arrêté. Suppression en attente de connexion ; réessaie ou rouvre l’app.")
                : String(localized: "Certaines séances attendent l’envoi. Ton entraînement reste disponible.")
        }
    }

    private func request(_ method: String, path: String, token: String, body: Data?) async throws {
        guard let endpoint else { throw URLError(.badURL) }
        var request = URLRequest(url: endpoint.appendingPathComponent("v1/" + path))
        request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 15
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (_, response) = try await transport.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private final class SharingNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private enum SharingKeychain {
    static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "fr.labonneseance.session-sharing", kSecAttrAccount as String: "enrollment"] }
    static func load() throws -> SharingEnrollment? {
        var q = query; q[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw URLError(.cannotOpenFile) }
        return try JSONDecoder().decode(SharingEnrollment.self, from: data)
    }
    static func save(_ value: SharingEnrollment?) throws {
        guard let value else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw URLError(.cannotWriteToFile) }
            return
        }
        let data = try JSONEncoder().encode(value)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; attributes.forEach { q[$0.key] = $0.value }
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw URLError(.cannotWriteToFile) }
        } else if status != errSecSuccess { throw URLError(.cannotWriteToFile) }
    }
}
