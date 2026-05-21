import Foundation
import CloudKit
import CryptoKit
import Security
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

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
        let environment = ProcessInfo.processInfo.environment
        if shouldDisableCloudKitForUITesting(environment: environment) {
            return false
        }
        return true
#endif
    }

    static func shouldDisableCloudKitForUITesting(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["EDITOR_UI_TEST_RESET_STORE"] == "1"
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
    private let accessible: CFString
    private let synchronizesAcrossDevices: Bool

    init(
        service: String = "com.liangzhang.editor.metadata",
        accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        synchronizesAcrossDevices: Bool = false
    ) {
        self.service = service
        self.accessible = accessible
        self.synchronizesAcrossDevices = synchronizesAcrossDevices
    }

    func setString(_ value: String, for account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainMetadataStoreError.invalidStringEncoding
        }

        try setData(data, for: account)
    }

    func setData(_ data: Data, for account: String) throws {
        try removeValue(for: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: accessible,
            kSecValueData as String: data
        ].includingSynchronizableFlag(synchronizesAcrossDevices)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainMetadataStoreError.unexpectedStatus(status)
        }
    }

    func string(for account: String) throws -> String? {
        guard let data = try data(for: account) else {
            return nil
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainMetadataStoreError.invalidStoredData
        }
        return value
    }

    func data(for account: String) throws -> Data? {
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
        guard let data = item as? Data else {
            throw KeychainMetadataStoreError.invalidStoredData
        }
        return data
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
        ].includingSynchronizableFlag(synchronizesAcrossDevices)
    }
}

enum KeychainMetadataStoreError: Error, Equatable {
    case invalidStringEncoding
    case invalidStoredData
    case unexpectedStatus(OSStatus)
}

protocol EncryptedNoteCiphering {
    func encrypt(_ plaintext: String) throws -> String
    func decrypt(_ storedValue: String) throws -> String
    func isCiphertext(_ storedValue: String) -> Bool
}

struct EncryptedNoteCipher: EncryptedNoteCiphering {
    static let ciphertextPrefix = "enc:v1:"
    private static let masterKeyAccount = "encrypted-notes.master-key.v1"

    private let metadataStore: KeychainMetadataStore

    init(
        metadataStore: KeychainMetadataStore = KeychainMetadataStore(
            service: "com.liangzhang.editor.encrypted-notes",
            accessible: kSecAttrAccessibleAfterFirstUnlock,
            synchronizesAcrossDevices: true
        )
    ) {
        self.metadataStore = metadataStore
    }

    func encrypt(_ plaintext: String) throws -> String {
        guard !isCiphertext(plaintext) else {
            return plaintext
        }

        let plaintextData = Data(plaintext.utf8)
        let key = SymmetricKey(data: try masterKeyData())
        let sealedBox = try AES.GCM.seal(plaintextData, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptedNoteCipherError.missingCombinedCiphertext
        }

        return Self.ciphertextPrefix + combined.base64EncodedString()
    }

    func decrypt(_ storedValue: String) throws -> String {
        guard isCiphertext(storedValue) else {
            return storedValue
        }

        let encoded = String(storedValue.dropFirst(Self.ciphertextPrefix.count))
        guard let combined = Data(base64Encoded: encoded) else {
            throw EncryptedNoteCipherError.invalidCiphertext
        }

        let key = SymmetricKey(data: try masterKeyData())
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let plaintextData = try AES.GCM.open(sealedBox, using: key)
        guard let plaintext = String(data: plaintextData, encoding: .utf8) else {
            throw EncryptedNoteCipherError.invalidPlaintext
        }

        return plaintext
    }

    func isCiphertext(_ storedValue: String) -> Bool {
        storedValue.hasPrefix(Self.ciphertextPrefix)
    }

    private func masterKeyData() throws -> Data {
        if let existingKey = try metadataStore.data(for: Self.masterKeyAccount) {
            return existingKey
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { buffer in
            Data(buffer)
        }
        try metadataStore.setData(keyData, for: Self.masterKeyAccount)
        return keyData
    }
}

enum EncryptedNoteCipherError: Error, Equatable {
    case missingCombinedCiphertext
    case invalidCiphertext
    case invalidPlaintext
}

@MainActor
protocol EncryptedPageAuthenticating {
    func authenticateForEncryptedPage() async -> Bool
}

struct SystemEncryptedPageAuthenticator: EncryptedPageAuthenticating {
    private let localizedReason: String

    init(localizedReason: String = "解锁加密内容") {
        self.localizedReason = localizedReason
    }

    func authenticateForEncryptedPage() async -> Bool {
#if canImport(LocalAuthentication)
        let context = LAContext()
        var policyError: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &policyError) else {
            EditorLog.security.error(
                "encrypted_page_auth_unavailable error=\(String(describing: policyError), privacy: .public)"
            )
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: localizedReason) { success, error in
                if success {
                    EditorLog.security.debug("encrypted_page_auth_succeeded")
                } else {
                    EditorLog.security.error(
                        "encrypted_page_auth_failed error=\(String(describing: error), privacy: .public)"
                    )
                }
                continuation.resume(returning: success)
            }
        }
#else
        EditorLog.security.error("encrypted_page_auth_unavailable error=local_authentication_missing")
        return false
#endif
    }
}

private extension Dictionary where Key == String, Value == Any {
    func includingSynchronizableFlag(_ isSynchronizable: Bool) -> [String: Any] {
        guard isSynchronizable else {
            return self
        }

        var copy = self
        copy[kSecAttrSynchronizable as String] = kCFBooleanTrue
        return copy
    }
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

    init(container: CKContainer = CKContainer(identifier: CloudKitSyncConfiguration.containerIdentifier)) {
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
