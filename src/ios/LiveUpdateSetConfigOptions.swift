import Foundation

@objc public class LiveUpdateSetConfigOptions: NSObject {
    let appId: String?

    init(_ options: [String: Any]) {
        self.appId = options["appId"] as? String
    }

    public func getAppId() -> String? {
        return appId
    }
}
