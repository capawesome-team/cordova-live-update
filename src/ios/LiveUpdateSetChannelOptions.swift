import Foundation

@objc public class LiveUpdateSetChannelOptions: NSObject {
    private var channel: String?

    init(channel: String?) {
        self.channel = channel
    }

    func getChannel() -> String? {
        return channel
    }
}
