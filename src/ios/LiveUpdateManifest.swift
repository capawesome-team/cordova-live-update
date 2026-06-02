import Foundation

@objc public class LiveUpdateManifest: NSObject, Codable {
    let items: [LiveUpdateManifestItem]

    init(items: [LiveUpdateManifestItem]) {
        self.items = items
    }

    public static func findDuplicateItems(_ manifest1: LiveUpdateManifest, _ manifest2: LiveUpdateManifest) -> [LiveUpdateManifestItem] {
        let checksumSet = Set(manifest2.items.map { $0.checksum })
        return manifest1.items.filter { checksumSet.contains($0.checksum) }
    }

    public static func findMissingItems(_ manifest1: LiveUpdateManifest, _ manifest2: LiveUpdateManifest) -> [LiveUpdateManifestItem] {
        let checksumSet = Set(manifest2.items.map { $0.checksum })
        return manifest1.items.filter { !checksumSet.contains($0.checksum) }
    }
}
