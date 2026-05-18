import Foundation

@objc public class LiveUpdateGetBlockedBundlesResult: NSObject, LiveUpdateResult {
    let bundleIds: [String]

    init(bundleIds: [String]) {
        self.bundleIds = bundleIds
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["bundleIds"] = bundleIds
        return result
    }
}
