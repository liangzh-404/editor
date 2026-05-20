import Foundation

enum CloudKitSyncGeneration {
    static let current = "editor-cloudkit-v2"
}

enum LocalSyncGenerationResetPolicy {
    private static let storeDirectoryName = "Editor"
    private static let markerFilename = ".sync-generation"

    static func prepareStoreDirectory(
        applicationSupportRoot: URL,
        currentGeneration: String = CloudKitSyncGeneration.current,
        fileManager: FileManager = .default
    ) throws -> URL {
        let storeDirectory = applicationSupportRoot
            .appendingPathComponent(storeDirectoryName, isDirectory: true)
        let markerURL = storeDirectory.appendingPathComponent(markerFilename)
        let storedGeneration = try? String(contentsOf: markerURL, encoding: .utf8)

        if storedGeneration != currentGeneration,
           fileManager.fileExists(atPath: storeDirectory.path) {
            try fileManager.removeItem(at: storeDirectory)
            EditorLog.sync.debug("local_sync_generation_reset reason=generation_mismatch")
        }

        try fileManager.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
        try currentGeneration.write(to: markerURL, atomically: true, encoding: .utf8)
        return storeDirectory
    }
}
