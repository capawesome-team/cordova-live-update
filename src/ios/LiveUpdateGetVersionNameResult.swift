import Foundation

@objc public class LiveUpdateGetVersionNameResult: NSObject, LiveUpdateResult {
    let versionName: String

    init(versionName: String) {
        self.versionName = versionName
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["versionName"] = versionName
        return result
    }
}
