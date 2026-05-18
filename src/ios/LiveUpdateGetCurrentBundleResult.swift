import Foundation

@objc public class LiveUpdateGetCurrentBundleResult: NSObject, LiveUpdateResult {
    let bundleId: String?

    init(bundleId: String?) {
        self.bundleId = bundleId
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["bundleId"] = bundleId == nil ? NSNull() : bundleId
        return result
    }
}
