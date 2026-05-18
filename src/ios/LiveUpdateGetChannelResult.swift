import Foundation

@objc public class LiveUpdateGetChannelResult: NSObject, LiveUpdateResult {
    let channel: String?

    init(channel: String?) {
        self.channel = channel
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["channel"] = channel == nil ? NSNull() : channel
        return result
    }
}
