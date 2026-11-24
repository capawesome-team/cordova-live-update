import Foundation

@objc public class LiveUpdateDownloadBundleOptions: NSObject {
    private var artifactType: LiveUpdateArtifactType
    private var bundleId: String
    private var checksum: String?
    private var signature: String?
    private var url: String
    /// The template for the files of the bundle, never set for a download from JavaScript.
    let urlTemplate: LiveUpdateUrlTemplate?

    init(artifactType: String, bundleId: String, checksum: String?, signature: String?, url: String) {
        if artifactType == "manifest" {
            self.artifactType = .manifest
        } else {
            self.artifactType = .zip
        }
        self.bundleId = bundleId
        self.checksum = checksum
        self.signature = signature
        self.url = url
        self.urlTemplate = nil
    }

    init(bundle: LiveUpdateCreateCheckResponse.Bundle) {
        self.artifactType = bundle.artifactType
        self.bundleId = bundle.id
        self.checksum = bundle.checksum
        self.signature = bundle.signature
        self.url = bundle.url
        self.urlTemplate = bundle.urlTemplate
    }

    func getArtifactType() -> LiveUpdateArtifactType {
        return artifactType
    }

    func getBundleId() -> String {
        return bundleId
    }

    func getChecksum() -> String? {
        return checksum
    }

    func getSignature() -> String? {
        return signature
    }

    func getUrl() -> String {
        return url
    }

    /// The checksum is always set with `urlTemplate`, because a bundle with a template and no checksum is not parsed.
    func requireChecksum() throws -> String {
        guard let checksum = checksum else {
            throw LiveUpdateError.checksumMissing
        }
        return checksum
    }
}
