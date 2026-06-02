import Foundation

@objc public class LiveUpdateSyncResult: NSObject, LiveUpdateResult {
    let nextBundleId: String?

    init(nextBundleId: String?) {
        self.nextBundleId = nextBundleId
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["nextBundleId"] = nextBundleId == nil ? NSNull() : nextBundleId
        return result
    }
}
