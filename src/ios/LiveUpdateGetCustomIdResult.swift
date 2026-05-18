import Foundation

@objc public class LiveUpdateGetCustomIdResult: NSObject, LiveUpdateResult {
    let customId: String?

    init(customId: String?) {
        self.customId = customId
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["customId"] = customId == nil ? NSNull() : customId
        return result
    }
}
