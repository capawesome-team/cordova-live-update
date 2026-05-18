import Foundation

@objc public class LiveUpdateIsSyncingResult: NSObject, LiveUpdateResult {
    let syncing: Bool

    init(syncing: Bool) {
        self.syncing = syncing
    }

    @objc public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["syncing"] = syncing
        return result
    }
}
