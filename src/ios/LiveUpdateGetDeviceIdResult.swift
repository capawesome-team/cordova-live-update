import Foundation

@objc public class LiveUpdateGetDeviceIdResult: NSObject, LiveUpdateResult {
    let deviceId: String

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["deviceId"] = deviceId
        return result
    }
}
