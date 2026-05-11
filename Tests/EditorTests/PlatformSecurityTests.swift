import Foundation
import CloudKit
import XCTest

final class PlatformSecurityTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testMacOSEntitlementsEnableSandboxAndUserSelectedReads() throws {
        let entitlementsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/EditorApp/EditorMac.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertEqual(plist["com.apple.security.files.user-selected.read-only"] as? Bool, true)
    }

    func testDataProtectionServiceKeepsProtectedFileReadable() throws {
        let fileURL = makeTemporaryDirectory().appendingPathComponent("protected.sqlite")
        try Data("protected".utf8).write(to: fileURL)

        try DataProtectionService.applyNativeProtection(to: fileURL)

        XCTAssertEqual(try Data(contentsOf: fileURL), Data("protected".utf8))
    }

    func testKeychainMetadataStoreRoundTripsAccountMetadata() throws {
        let store = KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        defer {
            try? store.removeValue(for: "icloud-account")
        }

        try store.setString("primary-account", for: "icloud-account")

        XCTAssertEqual(try store.string(for: "icloud-account"), "primary-account")

        try store.removeValue(for: "icloud-account")
        XCTAssertNil(try store.string(for: "icloud-account"))
    }

    func testCloudKitAccountMetadataServiceStoresMappedStatusInKeychain() throws {
        let store = KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        defer {
            try? store.removeValue(for: CloudKitAccountMetadataService.accountStatusKey)
        }
        let service = CloudKitAccountMetadataService(
            provider: StaticCloudKitAccountStatusProvider(status: .available),
            metadataStore: store
        )

        let status = try service.refreshAndStoreStatus()

        XCTAssertEqual(status, .available)
        XCTAssertEqual(try service.lastStoredStatus(), .available)
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        temporaryFiles.append(directory)
        return directory
    }
}

private struct StaticCloudKitAccountStatusProvider: CloudKitAccountStatusProviding {
    let status: CKAccountStatus

    func accountStatus() throws -> CKAccountStatus {
        status
    }
}
