import Foundation

@objc public protocol LiveUpdateResult {
    @objc func toJSObject() -> [String: Any]
}
