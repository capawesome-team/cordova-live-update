import Foundation

@objc public class LiveUpdateManifest: NSObject, Codable {
    let items: [LiveUpdateManifestItem]

    init(items: [LiveUpdateManifestItem]) {
        self.items = items
    }

    /// - Returns: Per checksum, the first path that holds this content.
    func mapFirstHrefsByChecksum() -> [String: String] {
        var hrefsByChecksum = [String: String]()
        for item in items where hrefsByChecksum[item.checksum] == nil {
            hrefsByChecksum[item.checksum] = item.href
        }
        return hrefsByChecksum
    }

    /// - Returns: `nil` if the data is not a JSON list or an item cannot be used.
    static func parse(_ data: Data) -> LiveUpdateManifest? {
        guard let items = try? JSONDecoder().decode([LiveUpdateManifestItem].self, from: data) else {
            return nil
        }
        return LiveUpdateManifest(items: items)
    }
}
