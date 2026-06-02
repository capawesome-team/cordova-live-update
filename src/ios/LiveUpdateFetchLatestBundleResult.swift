import Foundation

@objc public class LiveUpdateFetchLatestBundleResult: NSObject, LiveUpdateResult {
    private let artifactType: LiveUpdateArtifactType?
    private let bundleId: String?
    private let checksum: String?
    private let customProperties: [String: Any]?
    private let downloadUrl: String?
    private let signature: String?

    init(artifactType: LiveUpdateArtifactType?, bundleId: String?, checksum: String?, customProperties: [String: Any]?, downloadUrl: String?, signature: String?) {
        self.artifactType = artifactType
        self.bundleId = bundleId
        self.checksum = checksum
        self.customProperties = customProperties
        self.downloadUrl = downloadUrl
        self.signature = signature
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        if artifactType == .manifest {
            result["artifactType"] = "manifest"
        } else if artifactType == .zip {
            result["artifactType"] = "zip"
        }
        result["bundleId"] = bundleId == nil ? NSNull() : bundleId
        if let checksum = checksum {
            result["checksum"] = checksum
        }
        if let customProperties = customProperties {
            result["customProperties"] = customProperties
        }
        if let downloadUrl = downloadUrl {
            result["downloadUrl"] = downloadUrl
        }
        if let signature = signature {
            result["signature"] = signature
        }
        return result
    }
}
