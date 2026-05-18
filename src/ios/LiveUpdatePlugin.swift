import Cordova
import Foundation
import UIKit
import WebKit

@objc(CapawesomeLiveUpdatePlugin)
public class LiveUpdatePlugin: CDVPlugin, CDVPluginSchemeHandler {
    public static let tag = "LiveUpdate"
    public static let version = "0.1.0"
    public static let userDefaultsPrefix = "CapawesomeLiveUpdate" // DO NOT CHANGE

    private let eventDownloadBundleProgress = "downloadBundleProgress"
    private let eventNextBundleSet = "nextBundleSet"
    private let eventReloaded = "reloaded"

    private static let errorAppIdMissing = "appId must be configured."
    private static let errorBundleIdMissing = "bundleId must be provided."
    private static let errorCustomIdMissing = "customId must be provided."
    private static let errorUrlMissing = "url must be provided."
    private static let errorListenerIdMissing = "listenerId must be provided."
    private static let errorPluginNotInitialized = "LiveUpdate plugin failed to initialize."
    private static let errorHttpTimeout = "Request timed out."

    private var config: LiveUpdateConfig?
    private var implementation: LiveUpdate?
    private var schemeHandler: LiveUpdateSchemeHandler?

    private struct ListenerRegistration {
        let eventName: String
        let callbackId: String
    }

    private let listenersLock = NSLock()
    private var listeners: [String: ListenerRegistration] = [:]

    public override func pluginInitialize() {
        super.pluginInitialize()
        let cfg = loadConfig()
        let handler = LiveUpdateSchemeHandler()
        let impl = LiveUpdate(config: cfg, plugin: self, schemeHandler: handler)
        self.config = cfg
        self.schemeHandler = handler
        self.implementation = impl
        impl.handleLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // MARK: - CDVPluginSchemeHandler conformance

    public func overrideSchemeTask(_ task: WKURLSchemeTask) -> Bool {
        return schemeHandler?.handle(task: task) ?? false
    }

    public func stopSchemeTask(_ task: WKURLSchemeTask) {
        schemeHandler?.stop(task: task)
    }

    // MARK: - Plugin → JS notify methods (called by LiveUpdate)

    func notifyDownloadBundleProgressListeners(_ event: LiveUpdateDownloadBundleProgressEvent) {
        notifyJSListeners(eventName: eventDownloadBundleProgress, data: event.toJSObject())
    }

    func notifyNextBundleSetListeners(_ event: LiveUpdateNextBundleSetEvent) {
        notifyJSListeners(eventName: eventNextBundleSet, data: event.toJSObject())
    }

    func notifyReloadedListeners() {
        notifyJSListeners(eventName: eventReloaded, data: [:])
    }

    public func reloadWebView() {
        DispatchQueue.main.async { [weak self] in
            guard let webView = self?.webViewEngine?.engineWebView as? WKWebView else {
                return
            }
            webView.reload()
        }
    }

    @objc private func handleAppWillEnterForeground() {
        implementation?.handleAppWillEnterForeground()
    }

    // MARK: - Action methods

    @objc(clearBlockedBundles:)
    func clearBlockedBundles(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        impl.clearBlockedBundles()
        resolve(command)
    }

    @objc(deleteBundle:)
    func deleteBundle(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        let options = optionsDict(from: command)
        guard let bundleId = string(options, "bundleId") else {
            reject(command, message: Self.errorBundleIdMissing)
            return
        }
        impl.deleteBundle(LiveUpdateDeleteBundleOptions(bundleId: bundleId)) { [weak self] error in
            self?.completeEmpty(command, error: error)
        }
    }

    @objc(downloadBundle:)
    func downloadBundle(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        let options = optionsDict(from: command)
        let artifactType = (options["artifactType"] as? String) ?? "zip"
        guard let bundleId = string(options, "bundleId") else {
            reject(command, message: Self.errorBundleIdMissing)
            return
        }
        let checksum = string(options, "checksum")
        let signature = string(options, "signature")
        guard let url = string(options, "url") else {
            reject(command, message: Self.errorUrlMissing)
            return
        }
        Task {
            do {
                try await impl.downloadBundle(LiveUpdateDownloadBundleOptions(
                    artifactType: artifactType,
                    bundleId: bundleId,
                    checksum: checksum,
                    signature: signature,
                    url: url
                ))
                resolve(command)
            } catch {
                reject(command, error: error)
            }
        }
    }

    @objc(fetchChannels:)
    func fetchChannels(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation, let cfg = config else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        guard let appId = cfg.appId, !appId.isEmpty else {
            reject(command, message: Self.errorAppIdMissing)
            return
        }
        let options = optionsDict(from: command)
        Task {
            do {
                let result = try await impl.fetchChannels(LiveUpdateFetchChannelsOptions(options))
                resolve(command, data: result.toJSObject())
            } catch {
                reject(command, error: error)
            }
        }
    }

    @objc(fetchLatestBundle:)
    func fetchLatestBundle(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation, let cfg = config else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        guard let appId = cfg.appId, !appId.isEmpty else {
            reject(command, message: Self.errorAppIdMissing)
            return
        }
        let options = optionsDict(from: command)
        Task {
            do {
                let result = try await impl.fetchLatestBundle(LiveUpdateFetchLatestBundleOptions(options))
                resolve(command, data: result.toJSObject())
            } catch {
                reject(command, error: error)
            }
        }
    }

    @objc(getBlockedBundles:)
    func getBlockedBundles(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getBlockedBundles(completion: completion) }
    }

    @objc(getBundles:)
    func getBundles(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getBundles(completion: completion) }
    }

    @objc(getChannel:)
    func getChannel(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getChannel(completion: completion) }
    }

    @objc(getConfig:)
    func getConfig(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getConfig(completion: completion) }
    }

    @objc(getCurrentBundle:)
    func getCurrentBundle(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getCurrentBundle(completion: completion) }
    }

    @objc(getCustomId:)
    func getCustomId(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getCustomId(completion: completion) }
    }

    @objc(getDeviceId:)
    func getDeviceId(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getDeviceId(completion: completion) }
    }

    @objc(getDownloadedBundles:)
    func getDownloadedBundles(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getDownloadedBundles(completion: completion) }
    }

    @objc(getNextBundle:)
    func getNextBundle(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getNextBundle(completion: completion) }
    }

    @objc(getVersionCode:)
    func getVersionCode(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getVersionCode(completion: completion) }
    }

    @objc(getVersionName:)
    func getVersionName(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.getVersionName(completion: completion) }
    }

    @objc(isSyncing:)
    func isSyncing(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.isSyncing(completion: completion) }
    }

    @objc(ready:)
    func ready(_ command: CDVInvokedUrlCommand) {
        completeResult(command) { impl, completion in impl.ready(completion: completion) }
    }

    @objc(reload:)
    func reload(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        impl.reload()
        resolve(command)
    }

    @objc(reset:)
    func reset(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        impl.reset()
        resolve(command)
    }

    @objc(resetConfig:)
    func resetConfig(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        impl.resetConfig()
        resolve(command)
    }

    @objc(setChannel:)
    func setChannel(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        let options = optionsDict(from: command)
        let channel = string(options, "channel")
        impl.setChannel(LiveUpdateSetChannelOptions(channel: channel)) { [weak self] error in
            self?.completeEmpty(command, error: error)
        }
    }

    @objc(setConfig:)
    func setConfig(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        let options = optionsDict(from: command)
        impl.setConfig(LiveUpdateSetConfigOptions(options))
        resolve(command)
    }

    @objc(setCustomId:)
    func setCustomId(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        let options = optionsDict(from: command)
        guard let customId = string(options, "customId") else {
            reject(command, message: Self.errorCustomIdMissing)
            return
        }
        impl.setCustomId(LiveUpdateSetCustomIdOptions(customId: customId)) { [weak self] error in
            self?.completeEmpty(command, error: error)
        }
    }

    @objc(setNextBundle:)
    func setNextBundle(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        let options = optionsDict(from: command)
        impl.setNextBundle(LiveUpdateSetNextBundleOptions(options)) { [weak self] error in
            self?.completeEmpty(command, error: error)
        }
    }

    @objc(sync:)
    func sync(_ command: CDVInvokedUrlCommand) {
        guard let impl = implementation, let cfg = config else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        guard let appId = cfg.appId, !appId.isEmpty else {
            reject(command, message: Self.errorAppIdMissing)
            return
        }
        let options = optionsDict(from: command)
        Task {
            do {
                let result = try await impl.sync(LiveUpdateSyncOptions(options))
                resolve(command, data: result.toJSObject())
            } catch {
                reject(command, error: error)
            }
        }
    }

    @objc(addListener:)
    func addListener(_ command: CDVInvokedUrlCommand) {
        guard let eventName = command.argument(at: 0) as? String,
              let listenerId = command.argument(at: 1) as? String else {
            reject(command, message: Self.errorListenerIdMissing)
            return
        }
        listenersLock.lock()
        listeners[listenerId] = ListenerRegistration(eventName: eventName, callbackId: command.callbackId)
        listenersLock.unlock()
        // Keep the callback alive so we can deliver future events to it.
        let result = CDVPluginResult(status: .noResult)
        result?.keepCallback = NSNumber(value: true)
        commandDelegate.send(result, callbackId: command.callbackId)
    }

    @objc(removeListener:)
    func removeListener(_ command: CDVInvokedUrlCommand) {
        let options = optionsDict(from: command)
        guard let listenerId = string(options, "listenerId") else {
            reject(command, message: Self.errorListenerIdMissing)
            return
        }
        listenersLock.lock()
        let removed = listeners.removeValue(forKey: listenerId)
        listenersLock.unlock()
        if let removed = removed {
            // Release the JS callback that was kept alive by addListener.
            let release = CDVPluginResult(status: .noResult)
            release?.keepCallback = NSNumber(value: false)
            commandDelegate.send(release, callbackId: removed.callbackId)
        }
        resolve(command)
    }

    @objc(removeAllListeners:)
    func removeAllListeners(_ command: CDVInvokedUrlCommand) {
        listenersLock.lock()
        let toRelease = Array(listeners.values)
        listeners.removeAll()
        listenersLock.unlock()
        for entry in toRelease {
            let release = CDVPluginResult(status: .noResult)
            release?.keepCallback = NSNumber(value: false)
            commandDelegate.send(release, callbackId: entry.callbackId)
        }
        resolve(command)
    }

    // MARK: - Helpers

    private func notifyJSListeners(eventName: String, data: [String: Any]) {
        listenersLock.lock()
        let recipients = listeners.values.filter { $0.eventName == eventName }
        listenersLock.unlock()
        for entry in recipients {
            let result = CDVPluginResult(status: .ok, messageAs: data)
            result?.keepCallback = NSNumber(value: true)
            commandDelegate.send(result, callbackId: entry.callbackId)
        }
    }

    private func optionsDict(from command: CDVInvokedUrlCommand) -> [String: Any] {
        return (command.argument(at: 0) as? [String: Any]) ?? [:]
    }

    private func string(_ options: [String: Any], _ key: String) -> String? {
        guard let value = options[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    private func completeEmpty(_ command: CDVInvokedUrlCommand, error: Error?) {
        if let error = error {
            reject(command, error: error)
        } else {
            resolve(command)
        }
    }

    private func completeResult(
        _ command: CDVInvokedUrlCommand,
        _ invoke: (LiveUpdate, @escaping (LiveUpdateResult?, Error?) -> Void) -> Void
    ) {
        guard let impl = implementation else {
            reject(command, message: Self.errorPluginNotInitialized)
            return
        }
        invoke(impl) { [weak self] result, error in
            if let error = error {
                self?.reject(command, error: error)
                return
            }
            if let result = result {
                self?.resolve(command, data: result.toJSObject())
            } else {
                self?.resolve(command)
            }
        }
    }

    private func resolve(_ command: CDVInvokedUrlCommand) {
        let result = CDVPluginResult(status: .ok)
        commandDelegate.send(result, callbackId: command.callbackId)
    }

    private func resolve(_ command: CDVInvokedUrlCommand, data: [String: Any]) {
        let result = CDVPluginResult(status: .ok, messageAs: data)
        commandDelegate.send(result, callbackId: command.callbackId)
    }

    private func reject(_ command: CDVInvokedUrlCommand, message: String) {
        let result = CDVPluginResult(status: .error, messageAs: message)
        commandDelegate.send(result, callbackId: command.callbackId)
    }

    private func reject(_ command: CDVInvokedUrlCommand, error: Error) {
        var message = error.localizedDescription
        if let urlError = error as? URLError, urlError.code == .timedOut {
            message = Self.errorHttpTimeout
        }
        NSLog("[\(Self.tag)] \(message)")
        reject(command, message: message)
    }

    private func loadConfig() -> LiveUpdateConfig {
        var cfg = LiveUpdateConfig()
        let info = Bundle.main.infoDictionary ?? [:]
        if let appId = info["LiveUpdateAppId"] as? String, !appId.isEmpty { cfg.appId = appId }
        if let defaultChannel = info["LiveUpdateDefaultChannel"] as? String, !defaultChannel.isEmpty { cfg.defaultChannel = defaultChannel }
        if let strategy = info["LiveUpdateAutoUpdateStrategy"] as? String, !strategy.isEmpty { cfg.autoUpdateStrategy = strategy }
        if let timeout = parseInt(info["LiveUpdateHttpTimeout"]) { cfg.httpTimeout = timeout }
        if let publicKey = info["LiveUpdatePublicKey"] as? String, !publicKey.isEmpty { cfg.publicKey = publicKey }
        if let timeout = parseInt(info["LiveUpdateReadyTimeout"]) { cfg.readyTimeout = timeout }
        if let domain = info["LiveUpdateServerDomain"] as? String, !domain.isEmpty { cfg.serverDomain = domain }
        if let value = parseBool(info["LiveUpdateAutoDeleteBundles"]) { cfg.autoDeleteBundles = value }
        if let value = parseBool(info["LiveUpdateAutoBlockRolledBackBundles"]) { cfg.autoBlockRolledBackBundles = value }
        return cfg
    }

    private func parseInt(_ value: Any?) -> Int? {
        if let s = value as? String, let i = Int(s) { return i }
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }

    private func parseBool(_ value: Any?) -> Bool? {
        if let s = value as? String { return (s as NSString).boolValue }
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return nil
    }
}
