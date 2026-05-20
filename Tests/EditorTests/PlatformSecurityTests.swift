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

    func testMacOSEntitlementsEnableNetworkClientForSync() throws {
        let plist = try entitlementsPlist(named: "EditorMac.entitlements")

        XCTAssertEqual(plist["com.apple.security.network.client"] as? Bool, true)
    }

    func testMacOSEntitlementsDeclareCloudKitPrivateContainer() throws {
        let plist = try entitlementsPlist(named: "EditorMac.entitlements")

        XCTAssertEqual(plist["com.apple.developer.icloud-services"] as? [String], ["CloudKit"])
        XCTAssertEqual(
            plist["com.apple.developer.icloud-container-identifiers"] as? [String],
            ["iCloud.com.liangzhang.editor.sync"]
        )
        XCTAssertEqual(
            plist["com.apple.developer.icloud-container-development-container-identifiers"] as? [String],
            ["iCloud.com.liangzhang.editor.sync"]
        )
        XCTAssertEqual(plist["com.apple.developer.icloud-container-environment"] as? String, "Development")
    }

    func testCloudKitCapabilityEntitlementsDeclarePrivateContainer() throws {
        let plist = try entitlementsPlist(named: "EditorCloudKit.entitlements")

        XCTAssertEqual(plist["com.apple.developer.icloud-services"] as? [String], ["CloudKit"])
        XCTAssertEqual(
            plist["com.apple.developer.icloud-container-identifiers"] as? [String],
            ["iCloud.com.liangzhang.editor.sync"]
        )
        XCTAssertEqual(
            plist["com.apple.developer.icloud-container-development-container-identifiers"] as? [String],
            ["iCloud.com.liangzhang.editor.sync"]
        )
        XCTAssertEqual(plist["com.apple.developer.icloud-container-environment"] as? String, "Development")
    }

    func testCloudKitRuntimeUsesEntitledContainerIdentifier() throws {
        let plist = try entitlementsPlist(named: "EditorCloudKit.entitlements")
        let entitledContainers = try XCTUnwrap(
            plist["com.apple.developer.icloud-container-identifiers"] as? [String]
        )

        XCTAssertEqual(CloudKitSyncConfiguration.containerIdentifier, "iCloud.com.liangzhang.editor.sync")
        XCTAssertTrue(entitledContainers.contains(CloudKitSyncConfiguration.containerIdentifier))
    }

    func testIOSEntitlementsDeclareCloudKitPrivateContainer() throws {
        let plist = try entitlementsPlist(named: "EditorIOS.entitlements")

        XCTAssertEqual(plist["com.apple.developer.icloud-services"] as? [String], ["CloudKit"])
        XCTAssertEqual(
            plist["com.apple.developer.icloud-container-identifiers"] as? [String],
            ["iCloud.com.liangzhang.editor.sync"]
        )
        XCTAssertEqual(
            plist["com.apple.developer.icloud-container-development-container-identifiers"] as? [String],
            ["iCloud.com.liangzhang.editor.sync"]
        )
        XCTAssertEqual(plist["com.apple.developer.icloud-container-environment"] as? String, "Development")
    }

    func testIOSProjectDeclaresRemoteNotificationBackgroundMode() throws {
        let plist = try appPlist(named: "EditorIOS-Info.plist")

        XCTAssertEqual(plist["UIBackgroundModes"] as? [String], ["remote-notification"])
    }

    func testIOSEntitlementsDeclareDevelopmentPushNotificationEnvironment() throws {
        let plist = try entitlementsPlist(named: "EditorIOS.entitlements")

        XCTAssertEqual(plist["aps-environment"] as? String, "development")
    }

    func testIOSAppDelegateRegistersForRemoteNotificationsOnLaunch() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/EditorApp/EditorApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("didFinishLaunchingWithOptions"))
        XCTAssertTrue(source.contains("RemoteNotificationRegistrationPolicy.registerIfNeeded"))
    }

    func testIOSAppDelegatePersistsRemoteNotificationRegistrationDiagnostics() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/EditorApp/EditorApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("didRegisterForRemoteNotificationsWithDeviceToken"))
        XCTAssertTrue(source.contains("didFailToRegisterForRemoteNotificationsWithError"))
        XCTAssertTrue(source.contains("AppEnvironment.recordRuntimeDiagnostic"))
        XCTAssertTrue(source.contains("remote_notification_registration_succeeded"))
        XCTAssertTrue(source.contains("remote_notification_registration_failed"))
    }

    func testIOSAppDelegateRunsRemoteNotificationSyncOffMainCallback() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/EditorApp/EditorApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("didReceiveRemoteNotification"))
        XCTAssertTrue(source.contains("DispatchQueue.global(qos: .utility).async"))
        XCTAssertTrue(source.contains("AppEnvironment.handleRemoteNotificationSync()"))
        XCTAssertTrue(source.contains("DispatchQueue.main.async"))
        XCTAssertTrue(source.contains("completionHandler(result.uiBackgroundFetchResult)"))
    }

    func testCloudKitSyncDiagnosticRequestParsesHeadlessLaunchEnvironment() {
        let request = CloudKitSyncDiagnosticRequest(environment: [
            "EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC": "1",
            "EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_APPEND_TEXT": "mac to ios",
            "EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_PAGE_ID": "page-welcome"
        ])

        XCTAssertEqual(request?.appendText, "mac to ios")
        XCTAssertEqual(request?.pageID, "page-welcome")
        XCTAssertNil(CloudKitSyncDiagnosticRequest(environment: [:]))
    }

    func testCloudKitRuntimeProbeDiagnosticRequestParsesHeadlessLaunchEnvironment() {
        XCTAssertNotNil(CloudKitRuntimeProbeDiagnosticRequest(environment: [
            "EDITOR_CLOUDKIT_RUNTIME_PROBE_DIAGNOSTIC": "1"
        ]))
        XCTAssertNil(CloudKitRuntimeProbeDiagnosticRequest(environment: [:]))
        XCTAssertNil(CloudKitRuntimeProbeDiagnosticRequest(environment: [
            "EDITOR_CLOUDKIT_RUNTIME_PROBE_DIAGNOSTIC": "0"
        ]))
    }

    func testCloudKitRuntimeProbeDiagnosticPersistsReadableRuntimeEvent() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/EditorApp/AppEnvironment.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("CloudKitRuntimeProbeDiagnosticView"))
        XCTAssertTrue(source.contains("runCloudKitRuntimeProbeDiagnostic"))
        XCTAssertTrue(source.contains("cloudkit_runtime_probe_completed"))
        XCTAssertTrue(source.contains("cloudkit_runtime_probe_failed"))
        XCTAssertTrue(source.contains("recordRuntimeDiagnostic"))
    }

    func testRemoteNotificationSyncDiagnosticRequestParsesHeadlessLaunchEnvironment() {
        XCTAssertNotNil(RemoteNotificationSyncDiagnosticRequest(environment: [
            "EDITOR_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC": "1"
        ]))
        XCTAssertNil(RemoteNotificationSyncDiagnosticRequest(environment: [:]))
        XCTAssertNil(RemoteNotificationSyncDiagnosticRequest(environment: [
            "EDITOR_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC": "0"
        ]))
    }

    func testManualSyncEntryPointsAreNotExposedInMenuOrCompactUI() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: projectRoot.appendingPathComponent("Sources/EditorApp/EditorApp.swift"),
            encoding: .utf8
        )
        let shellSource = try String(
            contentsOf: projectRoot.appendingPathComponent("Sources/EditorCore/Features/Shell/EditorShellView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(appSource.contains("@FocusedValue(\\.syncNowAction)"))
        XCTAssertFalse(appSource.contains("CommandMenu(\"同步\")"))
        XCTAssertFalse(shellSource.contains(".focusedValue(\\.syncNowAction"))
        XCTAssertFalse(shellSource.contains("editor.compact.sync-now"))
        XCTAssertFalse(shellSource.contains("arrow.triangle.2.circlepath"))
    }

    func testEditorShellSyncsOnInitialActiveAppearAndLaterActivation() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shellSource = try String(
            contentsOf: projectRoot.appendingPathComponent("Sources/EditorCore/Features/Shell/EditorShellView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(shellSource.contains(".onAppear {\n                if foregroundSyncActivationPolicy.shouldSync(for: scenePhase) {\n                    viewModel.syncAfterActivation()\n                }\n            }"))
        XCTAssertTrue(shellSource.contains(".onChange(of: scenePhase) { _, phase in\n                if foregroundSyncActivationPolicy.shouldSync(for: phase) {\n                    viewModel.syncAfterActivation()\n                }\n            }"))
    }

    func testIOSProjectDeclaresLaunchScreenForFullResolutionPhones() throws {
        let plist = try appPlist(named: "EditorIOS-Info.plist")

        XCTAssertNotNil(
            plist["UILaunchScreen"] as? [String: Any],
            "iPhone renders letterboxed when the app bundle has no launch screen declaration."
        )
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

    func testCloudKitEntitlementInspectorRequiresContainerIdentifiers() {
        XCTAssertFalse(CloudKitEntitlementInspector.hasCloudKitContainers(entitlementValue: nil))
        XCTAssertFalse(CloudKitEntitlementInspector.hasCloudKitContainers(entitlementValue: [] as [String]))
        XCTAssertTrue(
            CloudKitEntitlementInspector.hasCloudKitContainers(
                entitlementValue: ["iCloud.com.liangzhang.editor.sync"]
            )
        )
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

    private func entitlementsPlist(named filename: String) throws -> [String: Any] {
        try appPlist(named: filename)
    }

    private func appPlist(named filename: String) throws -> [String: Any] {
        let entitlementsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/EditorApp")
            .appendingPathComponent(filename)
        let data = try Data(contentsOf: entitlementsURL)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }
}

private struct StaticCloudKitAccountStatusProvider: CloudKitAccountStatusProviding {
    let status: CKAccountStatus

    func accountStatus() throws -> CKAccountStatus {
        status
    }
}
