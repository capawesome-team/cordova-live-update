import Foundation

@objc public class LiveUpdateGetConfigResult: NSObject, LiveUpdateResult {
    let appId: String?
    let autoUpdateStrategy: String

    init(appId: String?, autoUpdateStrategy: String) {
        self.appId = appId
        self.autoUpdateStrategy = autoUpdateStrategy
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["appId"] = appId == nil ? NSNull() : appId
        result["autoUpdateStrategy"] = autoUpdateStrategy
        return result
    }
}
