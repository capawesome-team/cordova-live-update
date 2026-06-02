import Foundation

@objc public class LiveUpdateDeleteBundleOptions: NSObject {
    private var bundleId: String

    init(bundleId: String) {
        self.bundleId = bundleId
    }

    func getBundleId() -> String {
        return bundleId
    }
}
