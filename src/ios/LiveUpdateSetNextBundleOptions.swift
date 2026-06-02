import Foundation

@objc public class LiveUpdateSetNextBundleOptions: NSObject {
    private var bundleId: String?

    init(_ options: [String: Any]) {
        self.bundleId = options["bundleId"] as? String
    }

    func getBundleId() -> String? {
        return bundleId
    }
}
