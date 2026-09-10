import CryptoKit
import Foundation
import Security

final class SecureAuditStore {
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
        fileURL = directory.appendingPathComponent("audit-log.bin")
        key = try KeychainKey.loadOrCreate(service: "com.iosclaw.mac", account: "audit-log-key")
    }

    func load() throws -> [AuditEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let sealedData = try Data(contentsOf: fileURL)
        let box = try AES.GCM.SealedBox(combined: sealedData)
        let plaintext = try AES.GCM.open(box, using: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([AuditEvent].self, from: plaintext)
    }

    func save(_ events: [AuditEvent]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(events)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw StoreError.encryptionFailed }
        try combined.write(to: fileURL, options: .atomic)
    }

    enum StoreError: Error { case encryptionFailed }
}

private enum KeychainKey {
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
