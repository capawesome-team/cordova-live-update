import Foundation

/// An update that failed and is not reported to the server yet.
struct LiveUpdateFailure: Codable, Equatable {
    let appId: String
    let bundleId: String
    let reason: LiveUpdateFailureReason
}
