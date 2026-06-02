import Foundation

@objc public class LiveUpdateFetchChannelsOptions: NSObject {
    private var limit: Int?
    private var offset: Int?
    private var query: String?

    init(_ options: [String: Any]) {
        self.limit = options["limit"] as? Int
        self.offset = options["offset"] as? Int
        self.query = options["query"] as? String
    }

    func getLimit() -> Int? {
        return limit
    }

    func getOffset() -> Int? {
        return offset
    }

    func getQuery() -> String? {
        return query
    }
}
