import Foundation

@objc public class LiveUpdateGetVersionCodeResult: NSObject, LiveUpdateResult {
    let versionCode: String

    init(versionCode: String) {
        self.versionCode = versionCode
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["versionCode"] = versionCode
        return result
    }
}
