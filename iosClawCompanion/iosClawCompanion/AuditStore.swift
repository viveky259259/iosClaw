import Foundation

final class AuditStore: ObservableObject {
    @Published private(set) var steps: [AuditStep] = []

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let supportDirectory = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = supportDirectory.appendingPathComponent("iosClawCompanion", isDirectory: true)
        try! fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("audit-steps.json")
        load()
    }

    func append(_ step: AuditStep) {
        guard !steps.contains(where: { $0.id == step.id }) else { return }
        steps.append(step)
        steps.sort { $0.occurredAt > $1.occurredAt }
        persist()
    }

    func clear() {
        steps = []
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        steps = (try? decoder.decode([AuditStep].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        do {
            let data = try encoder.encode(steps)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        } catch {
            assertionFailure("Unable to persist the local audit timeline: \(error)")
        }
    }
}
