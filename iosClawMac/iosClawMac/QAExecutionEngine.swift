import CryptoKit
import Darwin
import Foundation

/// Executes one flow against one device. The file-backed lease is intentional:
/// it protects a device even if two iosClaw processes are open on the same Mac.
struct QAExecutionEngine {
    let client: WDAControlling
    let store: SecureQAStore

    func run(flow: QAFlow, deviceKey: String) async -> QARunRecord {
        var run = QARunRecord(flow: flow, deviceKey: deviceKey)
        var sessionID: String?
        do {
            let lease = try LocalDeviceLease(deviceKey: deviceKey)
            defer { lease.release() }

            sessionID = try await client.createSession(bundleID: flow.appBundleID)
            guard let sessionID else { throw WDAError.invalidResponse("WDA did not create a session") }

            for step in flow.steps {
                let start = ContinuousClock.now
                do {
                    try await client.perform(step, sessionID: sessionID)
                    if step.action == .screenshot || step.captureAfterStep {
                        let artifact = try store.saveScreenshot(try await client.screenshot(sessionID: sessionID), runID: run.id)
                        run.artifacts.append(artifact)
                    }
                    let elapsed = start.duration(to: .now)
                    run.events.append(QAStepEvent(
                        step: step,
                        outcome: .passed,
                        durationMilliseconds: elapsed.milliseconds,
                        detail: "Verified"
                    ))
                } catch {
                    let elapsed = start.duration(to: .now)
                    run.events.append(QAStepEvent(
                        step: step,
                        outcome: .failed,
                        durationMilliseconds: elapsed.milliseconds,
                        detail: error.localizedDescription
                    ))
                    if let image = try? await client.screenshot(sessionID: sessionID),
                       let artifact = try? store.saveScreenshot(image, runID: run.id) {
                        run.artifacts.append(artifact)
                    }
                    throw error
                }
            }
            run.outcome = .passed
        } catch {
            run.outcome = .failed
            run.failureSummary = error.localizedDescription
        }
        if let sessionID { await client.deleteSession(sessionID) }
        run.finishedAt = .now
        return run
    }
}

private final class LocalDeviceLease {
    private let descriptor: Int32

    init(deviceKey: String) throws {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("iosClaw/qa/leases", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = SHA256.hash(data: Data(deviceKey.utf8)).map { String(format: "%02x", $0) }.joined()
        let path = directory.appendingPathComponent("\(name).lock").path
        descriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw QAExecutionError.leaseUnavailable }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw QAExecutionError.deviceBusy
        }
    }

    func release() {
        guard descriptor >= 0 else { return }
        _ = flock(descriptor, LOCK_UN)
        _ = close(descriptor)
    }

    deinit { release() }
}

private enum QAExecutionError: LocalizedError {
    case deviceBusy
    case leaseUnavailable

    var errorDescription: String? {
        switch self {
        case .deviceBusy: "This device already has an active QA run."
        case .leaseUnavailable: "iosClaw could not acquire the local device lease."
        }
    }
}

private extension Duration {
    var milliseconds: Int {
        let components = components
        return Int(components.seconds * 1_000) + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
