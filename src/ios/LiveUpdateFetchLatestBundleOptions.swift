import Foundation

@objc public class LiveUpdateFetchLatestBundleOptions: NSObject {
    private var channel: String?

    init(_ options: [String: Any]) {
        self.channel = options["channel"] as? String
    }

    init(channel: String?) {
        self.channel = channel
    }

    func getChannel() -> String? {
        return channel
    }
}
