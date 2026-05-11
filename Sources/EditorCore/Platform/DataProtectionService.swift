import Foundation
import CloudKit
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

enum CloudKitEntitlementInspector {
    private static let containerIdentifiersKey = "com.apple.developer.icloud-container-identifiers"

    static func currentProcessHasCloudKitContainers() -> Bool {
#if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let entitlement = SecTaskCopyValueForEntitlement(
                task,
                containerIdentifiersKey as CFString,
                nil
              ) else {
            return false
        }

        return hasCloudKitContainers(entitlementValue: entitlement)
#else
        return true
#endif
    }

    static func hasCloudKitContainers(entitlementValue: Any?) -> Bool {
        guard let containers = entitlementValue as? [String] else {
            return false
        }

        return containers.contains { !$0.isEmpty }
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

enum CloudKitAccountAvailability: String, Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
}

protocol CloudKitAccountStatusProviding {
    func accountStatus() throws -> CKAccountStatus
}

final class LiveCloudKitAccountStatusProvider: CloudKitAccountStatusProviding {
    private let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    func accountStatus() throws -> CKAccountStatus {
        let semaphore = DispatchSemaphore(value: 0)
        final class StatusBox: @unchecked Sendable {
            var result: Result<CKAccountStatus, Error>?
        }
        let statusBox = StatusBox()

        container.accountStatus { status, error in
            if let error {
                statusBox.result = .failure(error)
            } else {
                statusBox.result = .success(status)
            }
            semaphore.signal()
        }
        semaphore.wait()

        return try statusBox.result?.get() ?? {
            throw CloudKitAccountMetadataError.missingStatus
        }()
    }
}

final class CloudKitAccountMetadataService {
    static let accountStatusKey = "cloudkit.account.status"

    private let provider: CloudKitAccountStatusProviding
    private let metadataStore: KeychainMetadataStore

    init(
        provider: CloudKitAccountStatusProviding = LiveCloudKitAccountStatusProvider(),
        metadataStore: KeychainMetadataStore = KeychainMetadataStore()
    ) {
        self.provider = provider
        self.metadataStore = metadataStore
    }

    func refreshAndStoreStatus() throws -> CloudKitAccountAvailability {
        let status = Self.availability(for: try provider.accountStatus())
        try metadataStore.setString(status.rawValue, for: Self.accountStatusKey)
        return status
    }

    func lastStoredStatus() throws -> CloudKitAccountAvailability? {
        guard let rawValue = try metadataStore.string(for: Self.accountStatusKey) else {
            return nil
        }
        return CloudKitAccountAvailability(rawValue: rawValue)
    }

    static func availability(for status: CKAccountStatus) -> CloudKitAccountAvailability {
        switch status {
        case .available:
            return .available
        case .noAccount:
            return .noAccount
        case .restricted:
            return .restricted
        case .couldNotDetermine:
            return .couldNotDetermine
        case .temporarilyUnavailable:
            return .temporarilyUnavailable
        @unknown default:
            return .couldNotDetermine
        }
    }
}

enum CloudKitAccountMetadataError: Error, Equatable {
    case missingStatus
}
