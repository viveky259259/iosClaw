import CryptoKit
import Foundation
import Security

/// Encrypted local persistence for manually recorded semantic flows. Input
/// values may be needed for deterministic replay, so the complete payload is
/// encrypted at rest and never included in audit or agent-list responses.
final class SecureActionFlowStore {
    private let fileURL: URL
    private let key: SymmetricKey

    init(fileManager: FileManager = .default) throws {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("iosClaw", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("recorded-action-flows.bin")
        key = try ActionFlowKeychainKey.loadOrCreate(
            service: "com.iosclaw.mac",
            account: "recorded-action-flow-key"
        )
    }

    func load() throws -> [RecordedActionFlow] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let sealedData = try Data(contentsOf: fileURL)
        let box = try AES.GCM.SealedBox(combined: sealedData)
        let plaintext = try AES.GCM.open(box, using: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([RecordedActionFlow].self, from: plaintext)
    }

    func save(_ flows: [RecordedActionFlow]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(Array(flows.prefix(500)))
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw StoreError.encryptionFailed }
        try combined.write(to: fileURL, options: .atomic)
    }

    enum StoreError: Error { case encryptionFailed }
}

/// Encrypted local persistence for compiled user drafts. A compiled package is
/// intentionally value-free, but it can still reveal a person's workflow, so
/// it gets an independent encryption key and never shares the recording key.
/// Only draft packages can enter this store: promotion to an executable flow
/// remains a separate, explicit lifecycle operation.
final class SecureCompiledFlowStore {
    private let fileURL: URL
    private let key: SymmetricKey

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        encryptionKey: SymmetricKey? = nil
    ) throws {
        let directory: URL
        if let directoryURL {
            directory = directoryURL
        } else {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directory = support.appendingPathComponent("iosClaw", isDirectory: true)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("compiled-flow-packages.bin")
        if let encryptionKey {
            key = encryptionKey
        } else {
            key = try ActionFlowKeychainKey.loadOrCreate(
                service: "com.iosclaw.mac",
                account: "compiled-flow-package-key"
            )
        }
    }

    func load() throws -> [CompiledFlowPackage] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let sealedData = try Data(contentsOf: fileURL)
        let box = try AES.GCM.SealedBox(combined: sealedData)
        let plaintext = try AES.GCM.open(box, using: key)
        return try JSONDecoder().decode([CompiledFlowPackage].self, from: plaintext)
    }

    func save(_ flows: [CompiledFlowPackage]) throws {
        guard flows.allSatisfy({
            $0.status == .draft && CompiledFlowValidator.validate($0).isEmpty
        }) else {
            throw StoreError.invalidPackage
        }
        let plaintext = try JSONEncoder().encode(Array(flows.prefix(500)))
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw StoreError.encryptionFailed }
        try combined.write(to: fileURL, options: .atomic)
    }

    enum StoreError: Error {
        case encryptionFailed
        case invalidPackage
    }
}

private enum ActionFlowKeychainKey {
    static func loadOrCreate(service: String, account: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }

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
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        return key
    }

    enum KeychainError: Error { case unexpectedStatus(OSStatus) }
}
