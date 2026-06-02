import Foundation

@objc public class LiveUpdateFetchChannelsResult: NSObject, LiveUpdateResult {
    private let channels: [LiveUpdateChannelResult]

    init(channels: [LiveUpdateChannelResult]) {
        self.channels = channels
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["channels"] = channels.map { $0.toJSObject() }
        return result
    }
}
