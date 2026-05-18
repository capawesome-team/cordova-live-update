import Foundation

@objc public class LiveUpdateReadyResult: NSObject, LiveUpdateResult {
    let currentBundleId: String?
    let previousBundleId: String?
    let rollback: Bool

    init(currentBundleId: String?, previousBundleId: String?, rollback: Bool) {
        self.currentBundleId = currentBundleId
        self.previousBundleId = previousBundleId
        self.rollback = rollback
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["currentBundleId"] = currentBundleId == nil ? NSNull() : currentBundleId
        result["previousBundleId"] = previousBundleId == nil ? NSNull() : previousBundleId
        result["rollback"] = rollback
        return result
    }
}
