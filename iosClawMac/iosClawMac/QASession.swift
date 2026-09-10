import AppKit
import Foundation

@MainActor
final class QASession: ObservableObject {
    @Published var endpointText = "http://127.0.0.1:8100"
    @Published private(set) var connectionStatus = "WebDriverAgent has not been checked."
    @Published private(set) var flows: [QAFlow] = []
    @Published private(set) var runs: [QARunRecord] = []
    @Published private(set) var isRunning = false
    @Published private(set) var activeFlowID: UUID?

    private let store: SecureQAStore?

    init() {
        store = try? SecureQAStore()
        let state = (try? store?.load()) ?? QAStoredState()
        flows = state.flows
        runs = state.runs
    }

    func testConnection() {
        Task {
            do {
                let client = try WDAClient(endpoint: try endpointURL())
                let detail = try await client.status()
                connectionStatus = "WebDriverAgent reachable: \(detail)"
            } catch {
                connectionStatus = "WebDriverAgent unavailable: \(error.localizedDescription)"
            }
        }
    }

    func saveFlow(fromJSON text: String) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let flow = try decoder.decode(QAFlow.self, from: Data(text.utf8))
        guard flow.schemaVersion == QAFlow.currentSchemaVersion else {
            throw QASessionError.unsupportedSchema(flow.schemaVersion)
        }
        guard !flow.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !flow.appBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !flow.steps.isEmpty
        else { throw QASessionError.invalidFlow }
        try save(flow: flow)
    }

    func save(flow: QAFlow) throws {
        var flow = flow
        flow.updatedAt = .now
        if let index = flows.firstIndex(where: { $0.id == flow.id }) {
            flows[index] = flow
        } else {
            flows.insert(flow, at: 0)
        }
        persist()
    }

    func deleteFlow(_ flow: QAFlow) {
        flows.removeAll { $0.id == flow.id }
        persist()
    }

    func flowJSON(_ flow: QAFlow) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(flow)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    func run(_ flow: QAFlow) {
        guard !isRunning else { return }
        isRunning = true
        activeFlowID = flow.id
        connectionStatus = "Running \(flow.name)…"
        Task {
            do {
                guard let store else { throw QASessionError.storeUnavailable }
                let endpoint = try endpointURL()
                let client = try WDAClient(endpoint: endpoint)
                let engine = QAExecutionEngine(client: client, store: store)
                let run = await engine.run(flow: flow, deviceKey: endpoint.absoluteString)
                runs.insert(run, at: 0)
                persist()
                connectionStatus = run.outcome == .passed
                    ? "Passed \(flow.name)."
                    : "Failed \(flow.name): \(run.failureSummary ?? "unknown failure")"
            } catch {
                connectionStatus = "Could not start \(flow.name): \(error.localizedDescription)"
            }
            isRunning = false
            activeFlowID = nil
        }
    }

    func screenshot(for artifact: QAArtifact) -> NSImage? {
        guard let store, let data = try? store.loadScreenshot(artifact) else { return nil }
        return NSImage(data: data)
    }

    private func endpointURL() throws -> URL {
        guard let url = URL(string: endpointText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw QASessionError.invalidEndpoint
        }
        return url
    }

    private func persist() {
        do {
            try store?.save(QAStoredState(flows: flows, runs: runs))
        } catch {
            connectionStatus = "QA data could not be saved: \(error.localizedDescription)"
        }
    }
}

enum QASessionError: LocalizedError {
    case invalidEndpoint
    case invalidFlow
    case unsupportedSchema(Int)
    case storeUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "Enter a valid loopback WebDriverAgent URL."
        case .invalidFlow: "A flow needs a name, app bundle identifier, and at least one step."
        case .unsupportedSchema(let version): "Flow schema \(version) is not supported by this iosClaw build."
        case .storeUnavailable: "Encrypted QA storage is unavailable."
        }
    }
}
