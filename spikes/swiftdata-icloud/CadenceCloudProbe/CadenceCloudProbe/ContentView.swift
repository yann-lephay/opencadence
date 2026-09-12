import CadencePersistenceSpike
import CloudKit
import SwiftUI

struct ContentView: View {
    @AppStorage("probeReplica") private var replica = "replica-a"
    @State private var payload = "baseline"
    @State private var accountStatus = "Not checked"
    @State private var controller: ProbeController?
    @State private var initializationError: String?
    @State private var isConfirmingCloudErase = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Environment") {
                    LabeledContent("iCloud account", value: accountStatus)
                    LabeledContent("Local source", value: "\(controller?.localValues.count ?? 0)")
                    LabeledContent("Cloud destination", value: "\(controller?.cloudValues.count ?? 0)")
                    Picker("Replica", selection: $replica) {
                        Text("Replica A").tag("replica-a")
                        Text("Replica B").tag("replica-b")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Canonical cloud value") {
                    if let canonical = controller?.canonicalCloudValue {
                        LabeledContent("Revision", value: "\(canonical.revision)")
                        LabeledContent("Writer", value: canonical.deviceID)
                        LabeledContent("State", value: canonical.isDeleted ? "Tombstone" : "Live")
                        LabeledContent("Payload", value: payloadText(canonical.payload))
                    } else {
                        Text("Cloud destination is empty")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Late activation proof") {
                    TextField("Payload", text: $payload)

                    Button("1. Seed local source") {
                        controller?.seedLocal(payload: payload, replica: replica)
                    }

                    Button("2. Copy local → CloudKit") {
                        controller?.copyLocalToCloud()
                    }

                    Button("Write cloud conflict") {
                        controller?.writeCloudConflict(
                            payload: payload,
                            replica: replica,
                            isDeleted: false
                        )
                    }

                    Button("Write matching tombstone", role: .destructive) {
                        controller?.writeCloudConflict(
                            payload: payload,
                            replica: replica,
                            isDeleted: true
                        )
                    }

                    Button("Erase cloud destination", role: .destructive) {
                        isConfirmingCloudErase = true
                    }
                }

                Section("Evidence") {
                    if let report = controller?.lastMigration {
                        LabeledContent("Source before", value: "\(report.sourceCount)")
                        LabeledContent("Cloud before", value: "\(report.destinationCountBefore)")
                        LabeledContent("Cloud after", value: "\(report.destinationCountAfter)")
                        Text(report.canonicalChecksum)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }

                    Text(controller?.operationStatus ?? initializationError ?? "Preparing stores…")
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }
            .confirmationDialog(
                "Erase the CloudKit destination?",
                isPresented: $isConfirmingCloudErase,
                titleVisibility: .visible
            ) {
                Button("Erase cloud destination", role: .destructive) {
                    controller?.eraseCloudDestination()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The local source is kept. Cloud deletions may sync to other devices.")
            }
            .navigationTitle("Cloud probe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Check iCloud") {
                        Task { await refreshAccountStatus() }
                    }
                }
            }
            .task {
                prepareStoresIfNeeded()
                await refreshAccountStatus()
            }
        }
    }

    @MainActor
    private func prepareStoresIfNeeded() {
        guard controller == nil, initializationError == nil else { return }
        do {
            controller = try ProbeController()
        } catch {
            initializationError = "Store setup failed: \(error.localizedDescription)"
        }
    }

    private func refreshAccountStatus() async {
        accountStatus = "Checking…"
        do {
            let status = try await CKContainer(
                identifier: ProbeConstants.containerIdentifier
            ).accountStatus()
            accountStatus = switch status {
            case .available: "Available"
            case .couldNotDetermine: "Could not determine"
            case .noAccount: "No account"
            case .restricted: "Restricted"
            case .temporarilyUnavailable: "Temporarily unavailable"
            @unknown default: "Unknown"
            }
        } catch {
            accountStatus = "Error: \(error.localizedDescription)"
        }
    }

    private func payloadText(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? data.base64EncodedString()
    }
}
