import Foundation

@objc public class LiveUpdateSetCustomIdOptions: NSObject {
    private var customId: String

    init(customId: String) {
        self.customId = customId
    }

    func getCustomId() -> String {
        return customId
    }
}
