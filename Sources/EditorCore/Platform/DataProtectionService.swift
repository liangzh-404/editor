import Foundation
import Security

enum DataProtectionService {
    static func applyNativeProtection(to url: URL) throws {
        var protectedURL = url

        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #else
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try protectedURL.setResourceValues(resourceValues)
        #endif

        EditorLog.store.debug("native_protection_applied path=\(url.lastPathComponent, privacy: .public)")
    }

    static func applyNativeProtectionRecursively(to directory: URL) throws {
        try applyNativeProtection(to: directory)

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            try applyNativeProtection(to: fileURL)
        }
    }
}

final class KeychainMetadataStore {
    private let service: String

    init(service: String = "com.liangzhang.editor.metadata") {
        self.service = service
    }

    func setString(_ value: String, for account: String) throws {
        try removeValue(for: account)

        guard let data = value.data(using: .utf8) else {
            throw KeychainMetadataStoreError.invalidStringEncoding
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainMetadataStoreError.unexpectedStatus(status)
        }
    }

    func string(for account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainMetadataStoreError.unexpectedStatus(status)
        }
        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainMetadataStoreError.invalidStoredData
        }
        return value
    }

    func removeValue(for account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainMetadataStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainMetadataStoreError: Error, Equatable {
    case invalidStringEncoding
    case invalidStoredData
    case unexpectedStatus(OSStatus)
}
