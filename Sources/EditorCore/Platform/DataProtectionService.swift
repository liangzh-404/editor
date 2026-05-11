import Foundation

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
