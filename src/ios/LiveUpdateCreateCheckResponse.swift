import Foundation

/// What the plugin reads from the answer to a check. A 200 that cannot be used means "no update".
struct LiveUpdateCreateCheckResponse {
    struct Bundle {
        let id: String
        let artifactType: LiveUpdateArtifactType
        /// Always set with `urlTemplate`.
        let checksum: String?
        let customProperties: [String: Any]?
        let signature: String?
        /// The plain address of the bundle: `url`, or else `legacyUrl`.
        let url: String
        let urlTemplate: LiveUpdateUrlTemplate?
    }

    private static let defaultRetryAfterMs: Int64 = 15 * 60 * 1000
    private static let maximumRetryAfterSeconds: Int64 = 24 * 60 * 60

    let bundle: Bundle?
    /// The reason as the server sent it, only set if the check was skipped.
    let reason: String?
    let result: LiveUpdateCheckResult?
    let retryAfterMs: Int64?

    /// An answer without an update and without a wait.
    static func createWithoutUpdate() -> LiveUpdateCreateCheckResponse {
        return LiveUpdateCreateCheckResponse(bundle: nil, reason: nil, result: nil, retryAfterMs: nil)
    }

    /// - Throws: `LiveUpdateError.requestFailed` for every status other than 200 and 429.
    static func parse(statusCode: Int, retryAfter: String?, body: String?) throws -> LiveUpdateCreateCheckResponse {
        switch statusCode {
        case 200:
            return parseBody(body)
        case 429:
            return LiveUpdateCreateCheckResponse(bundle: nil, reason: nil, result: nil, retryAfterMs: parseRetryAfterMs(retryAfter))
        default:
            throw LiveUpdateError.requestFailed(message: "The check failed with status \(statusCode).")
        }
    }

    /// - Returns: The text, or `nil` for a missing value, JSON `null`, a value that is no text or an empty text.
    private static func getNonEmptyString(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else {
            return nil
        }
        return text
    }

    private static func parseBody(_ body: String?) -> LiveUpdateCreateCheckResponse {
        guard let object = parseJsonObject(body) else {
            return createWithoutUpdate()
        }
        switch getNonEmptyString(object["result"]).flatMap(LiveUpdateCheckResult.init(rawValue:)) {
        case .available:
            guard let bundle = parseBundle(object["bundle"]) else {
                return createWithoutUpdate()
            }
            return LiveUpdateCreateCheckResponse(bundle: bundle, reason: nil, result: .available, retryAfterMs: nil)
        case .skipped:
            return LiveUpdateCreateCheckResponse(bundle: nil, reason: getNonEmptyString(object["reason"]), result: .skipped, retryAfterMs: nil)
        case .upToDate:
            return LiveUpdateCreateCheckResponse(bundle: parseBundle(object["bundle"]), reason: nil, result: .upToDate, retryAfterMs: nil)
        case nil:
            return createWithoutUpdate()
        }
    }

    /// The plain address is `url`, or else `legacyUrl`. A `urlTemplate` is optional, but it needs `checksum` and the placeholder.
    private static func parseBundle(_ object: Any?) -> Bundle? {
        guard let object = object as? [String: Any],
              let id = getNonEmptyString(object["id"]),
              let artifactType = getNonEmptyString(object["artifactType"]).flatMap(LiveUpdateArtifactType.init(rawValue:)),
              let url = getNonEmptyString(object["url"]) ?? getNonEmptyString(object["legacyUrl"]) else {
            return nil
        }
        let checksum = getNonEmptyString(object["checksum"])
        let urlTemplate = getNonEmptyString(object["urlTemplate"]).map(LiveUpdateUrlTemplate.init(value:))
        if let urlTemplate = urlTemplate, checksum == nil || !urlTemplate.hasChecksumPlaceholder {
            return nil
        }
        return Bundle(id: id, artifactType: artifactType, checksum: checksum,
                      customProperties: object["customProperties"] as? [String: Any],
                      signature: getNonEmptyString(object["signature"]), url: url, urlTemplate: urlTemplate)
    }

    private static func parseJsonObject(_ text: String?) -> [String: Any]? {
        guard let data = text?.data(using: .utf8) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Reads a whole number of seconds that is not negative. A number too large for `Int64` gives the maximum.
    private static func parseRetryAfterMs(_ retryAfter: String?) -> Int64 {
        guard let retryAfter = retryAfter, !retryAfter.isEmpty, retryAfter.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return defaultRetryAfterMs
        }
        let seconds = Int64(retryAfter) ?? maximumRetryAfterSeconds
        return min(seconds, maximumRetryAfterSeconds) * 1000
    }
}
