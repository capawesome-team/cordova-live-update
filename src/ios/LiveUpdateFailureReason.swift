import Foundation

enum LiveUpdateFailureReason: String, Codable {
    case bundleInvalid = "bundle_invalid"
    case checksumMismatched = "checksum_mismatched"
    case downloadFailed = "download_failed"
    case readinessTimedOut = "readiness_timed_out"
    case signatureVerificationFailed = "signature_verification_failed"

    /// Returns `nil` for an error that is not reported to the server.
    init?(error: Error) {
        switch error {
        case LiveUpdateError.bundleIndexHtmlMissing, LiveUpdateError.bundleUnzipFailed, LiveUpdateError.manifestInvalid:
            self = .bundleInvalid
        case LiveUpdateError.checksumMismatch:
            self = .checksumMismatched
        case LiveUpdateError.requestFailed:
            self = .downloadFailed
        case LiveUpdateError.signatureMissing, LiveUpdateError.signatureVerificationFailed:
            self = .signatureVerificationFailed
        default:
            return nil
        }
    }
}
