import CryptoKit
import Foundation
import Security

/// Encrypted local persistence for QA flow definitions and run metadata. Raw
/// screenshots live in independently encrypted files to avoid rewriting a large
/// metadata file on every capture.
final class SecureQAStore {
    private let directory: URL
    private let stateURL: URL
    private let artifactsDirectory: URL
    private let key: SymmetricKey

    init(
        fileManager: FileManager = .default,
        keychainService: String = "com.iosclaw.mac",
        keychainAccount: String = "qa-store-key",
        directoryURL: URL? = nil,
        encryptionKey: SymmetricKey? = nil
    ) throws {
        if let directoryURL {
            directory = directoryURL
        } else {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directory = support.appendingPathComponent("iosClaw/qa", isDirectory: true)
        }
        artifactsDirectory = directory.appendingPathComponent("artifacts", isDirectory: true)
        stateURL = directory.appendingPathComponent("state.bin")
        try fileManager.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)
        if let encryptionKey {
            key = encryptionKey
        } else {
            key = try QAKeychainKey.loadOrCreate(service: keychainService, account: keychainAccount)
        }
    }

    func load() throws -> QAStoredState {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return QAStoredState() }
        let sealedData = try Data(contentsOf: stateURL)
        let box = try AES.GCM.SealedBox(combined: sealedData)
        let plaintext = try AES.GCM.open(box, using: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(QAStoredState.self, from: plaintext)
    }

    func save(_ state: QAStoredState) throws {
        var state = state
        state.runs = Array(state.runs.prefix(500))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(state)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw QAStoreError.encryptionFailed }
        try combined.write(to: stateURL, options: .atomic)
    }

    func saveScreenshot(_ data: Data, runID: UUID) throws -> QAArtifact {
        let id = UUID()
        let filename = "\(runID.uuidString)-\(id.uuidString).bin"
        let fileURL = artifactsDirectory.appendingPathComponent(filename)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw QAStoreError.encryptionFailed }
        try combined.write(to: fileURL, options: .atomic)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return QAArtifact(id: id, kind: .screenshot, relativePath: filename, sha256: digest, createdAt: .now)
    }

    func loadScreenshot(_ artifact: QAArtifact) throws -> Data {
        let fileURL = artifactsDirectory.appendingPathComponent(artifact.relativePath)
        let sealedData = try Data(contentsOf: fileURL)
        let box = try AES.GCM.SealedBox(combined: sealedData)
        return try AES.GCM.open(box, using: key)
    }
}

struct QAStoredState: Codable {
    var flows: [QAFlow]
    var runs: [QARunRecord]

    init(flows: [QAFlow] = [], runs: [QARunRecord] = []) {
        self.flows = flows
        self.runs = runs
    }
}

enum QAStoreError: Error {
    case encryptionFailed
}

private enum QAKeychainKey {
    static func loadOrCreate(service: String, account: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound else { throw QAKeychainError.unexpectedStatus(status) }

        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data(Array($0)) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw QAKeychainError.unexpectedStatus(addStatus) }
        return key
    }

    enum QAKeychainError: Error {
        case unexpectedStatus(OSStatus)
    }
}
