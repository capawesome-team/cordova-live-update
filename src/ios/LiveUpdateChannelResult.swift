import Foundation

@objc public class LiveUpdateChannelResult: NSObject, LiveUpdateResult {
    private let id: String
    private let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public func toJSObject() -> [String: Any] {
        var result: [String: Any] = [:]
        result["id"] = id
        result["name"] = name
        return result
    }
}
