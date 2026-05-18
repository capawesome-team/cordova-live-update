public struct LiveUpdateGetLatestBundleResponse: Codable {
    var artifactType: LiveUpdateArtifactType
    var bundleId: String
    var checksum: String?
    var customProperties: [String: String]?
    var signature: String?
    var url: String
}
