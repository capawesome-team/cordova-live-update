import Foundation

@objc public class LiveUpdateNextBundleSetEvent: NSObject {
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
