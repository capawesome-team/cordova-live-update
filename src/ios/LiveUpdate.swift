import Foundation
import CryptoKit
import ZIPFoundation
import Alamofire
import CommonCrypto
import UIKit

// swiftlint:disable type_body_length
@objc public class LiveUpdate: NSObject {
    private let autoUpdateIntervalMs: Int64 = 15 * 60 * 1000 // 15 minutes
    private let bundlesDirectory = "NoCloud/capawesome_live_update_bundles" // DO NOT CHANGE!
    private let cachesDirectoryUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    private let config: LiveUpdateConfig
    private let defaultWebAssetDir = "www" // Cordova builds place web assets under "www/" inside the app bundle.
    private let httpClient: LiveUpdateHttpClient
    private let libraryDirectoryUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    private let manifestFileName = "capawesome-live-update-manifest.json" // DO NOT CHANGE!
    private let plugin: LiveUpdatePlugin
    private let preferences: LiveUpdatePreferences
    private let schemeHandler: LiveUpdateSchemeHandler

    private var rollbackDispatchWorkItem: DispatchWorkItem?
    private var rollbackPerformed = false
    private var lastAutoUpdateCheckTimestamp: Int64 = 0
    private var syncInProgress = false

    init(config: LiveUpdateConfig, plugin: LiveUpdatePlugin, schemeHandler: LiveUpdateSchemeHandler) {
        self.config = config
        self.httpClient = LiveUpdateHttpClient(config: config)
        self.plugin = plugin
        self.preferences = LiveUpdatePreferences()
        self.schemeHandler = schemeHandler
        super.init()

        // Promote the persisted next bundle to active for this session. This
        // matches Capacitor's launch-time behavior where the persisted next
        // path becomes the current server base path on each cold start.
        if let nextBundleId = preferences.getNextBundleId(), hasBundleById(nextBundleId) {
            schemeHandler.activeBundleDir = buildBundleURLFor(bundleId: nextBundleId)
        }

        // Check version and reset config if version changed
        checkAndResetConfigIfVersionChanged()

        // Set the device ID on the HTTP client (after any potential config reset)
        self.httpClient.setDeviceId(getDeviceId())

        // Start the rollback timer to rollback to the default bundle
        // if the app is not ready after a certain time
        startRollbackTimer()
    }

    @objc public func clearBlockedBundles() {
        preferences.setBlockedBundleIds(nil)
    }

    @objc public func deleteBundle(_ options: LiveUpdateDeleteBundleOptions, completion: @escaping (Error?) -> Void) {
        let bundleId = options.getBundleId()

        if !hasBundleById(bundleId) {
            completion(LiveUpdateError.bundleNotFound)
            return
        }

        do {
            try deleteBundleById(bundleId)
            completion(nil)
        } catch {
            completion(error)
        }
    }

    @objc public func downloadBundle(_ options: LiveUpdateDownloadBundleOptions) async throws {
        let artifactType = options.getArtifactType()
        let bundleId = options.getBundleId()
        let checksum = options.getChecksum()
        let signature = options.getSignature()
        let url = options.getUrl()

        if hasBundleById(bundleId) {
            throw LiveUpdateError.bundleAlreadyExists
        }

        if artifactType == .manifest {
            try await downloadBundleOfTypeManifest(bundleId: bundleId, url: url)
        } else {
            try await downloadBundleOfTypeZip(bundleId: bundleId, checksum: checksum, signature: signature, url: url)
        }
    }

    @objc public func fetchChannels(_ options: LiveUpdateFetchChannelsOptions) async throws -> LiveUpdateFetchChannelsResult {
        var parameters = [String: String]()
        if let limit = options.getLimit() {
            parameters["limit"] = String(limit)
        }
        if let offset = options.getOffset() {
            parameters["offset"] = String(offset)
        }
        if let query = options.getQuery() {
            parameters["query"] = query
        }
        var urlComponents = URLComponents(string: "https://\(config.serverDomain)/v1/apps/\(getAppId() ?? "")/channels")!
        if !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let url = try urlComponents.asURL()
        let response = try await self.httpClient.request(url: url, type: [LiveUpdateGetChannelsResponseItem].self)
        if let error = response.error {
            if response.response?.statusCode == 401 {
                throw LiveUpdateError.channelDiscoveryNotEnabled
            }
            if let urlError = error.underlyingError as? URLError, urlError.code == .timedOut {
                throw urlError
            }
            throw error
        }
        let items = response.value ?? []
        let channels = items.map { LiveUpdateChannelResult(id: $0.id, name: $0.name) }
        return LiveUpdateFetchChannelsResult(channels: channels)
    }

    @objc public func fetchLatestBundle(_ options: LiveUpdateFetchLatestBundleOptions) async throws -> LiveUpdateFetchLatestBundleResult {
        let response: LiveUpdateGetLatestBundleResponse? = try await self.fetchLatestBundle(options)
        return LiveUpdateFetchLatestBundleResult(
            artifactType: response?.artifactType,
            bundleId: response?.bundleId,
            checksum: response?.checksum,
            customProperties: response?.customProperties,
            downloadUrl: response?.url,
            signature: response?.signature
        )
    }

    @objc public func getBlockedBundles(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        var bundleIds: [String] = []
        if let blockedIds = preferences.getBlockedBundleIds(), !blockedIds.isEmpty {
            bundleIds = blockedIds.split(separator: ",").map(String.init)
        }
        completion(LiveUpdateGetBlockedBundlesResult(bundleIds: bundleIds), nil)
    }

    @objc public func getBundles(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetBundlesResult(bundleIds: getDownloadedBundleIds()), nil)
    }

    @objc public func getDownloadedBundles(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetDownloadedBundlesResult(bundleIds: getDownloadedBundleIds()), nil)
    }

    @objc public func getChannel(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetChannelResult(channel: getChannel()), nil)
    }

    @objc public func getConfig(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetConfigResult(appId: getAppId(), autoUpdateStrategy: config.autoUpdateStrategy), nil)
    }

    @objc public func getCurrentBundle(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetCurrentBundleResult(bundleId: getCurrentBundleId()), nil)
    }

    @objc public func getCustomId(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetCustomIdResult(customId: preferences.getCustomId()), nil)
    }

    @objc public func getDeviceId(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetDeviceIdResult(deviceId: getDeviceId()), nil)
    }

    @objc public func getNextBundle(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetNextBundleResult(bundleId: getNextBundleId()), nil)
    }

    @objc public func getVersionCode(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetVersionCodeResult(versionCode: getVersionCode()), nil)
    }

    @objc public func getVersionName(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateGetVersionNameResult(versionName: getVersionName()), nil)
    }

    @objc public func isSyncing(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        completion(LiveUpdateIsSyncingResult(syncing: syncInProgress), nil)
    }

    @objc public func handleLoad() {
        if config.autoUpdateStrategy == "background" {
            performAutoUpdate()
        }
    }

    @objc public func handleAppWillEnterForeground() {
        if config.autoUpdateStrategy == "background" {
            performAutoUpdate()
        }
    }

    @objc public func ready(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        NSLog("[\(LiveUpdatePlugin.tag)] App is ready.")
        if config.readyTimeout <= 0 {
            NSLog("[\(LiveUpdatePlugin.tag)] Ready timeout is set to 0. Automatic rollback is disabled.")
        }
        stopRollbackTimer()
        if config.autoDeleteBundles {
            deleteUnusedBundles()
        }
        let currentBundleId = getCurrentBundleId()
        let previousBundleId = getPreviousBundleId()
        if config.autoBlockRolledBackBundles && rollbackPerformed, let previousBundleId = previousBundleId {
            addBlockedBundleId(previousBundleId)
        }
        let result = LiveUpdateReadyResult(currentBundleId: currentBundleId, previousBundleId: previousBundleId, rollback: rollbackPerformed)
        completion(result, nil)
        setPreviousBundleId(bundleId: currentBundleId)
        rollbackPerformed = false
    }

    @objc public func reload() {
        let nextBundleId = getNextBundleId()
        setCurrentBundleById(nextBundleId)
        startRollbackTimer()
    }

    @objc public func reset() {
        setNextBundleById(nil)
    }

    @objc public func resetConfig() {
        preferences.setAppId(nil)
    }

    @objc public func setChannel(_ options: LiveUpdateSetChannelOptions, completion: @escaping (Error?) -> Void) {
        preferences.setChannel(options.getChannel())
        completion(nil)
    }

    @objc public func setConfig(_ options: LiveUpdateSetConfigOptions) {
        preferences.setAppId(options.getAppId())
    }

    @objc public func setCustomId(_ options: LiveUpdateSetCustomIdOptions, completion: @escaping (Error?) -> Void) {
        if let customId = options.getCustomId() {
            preferences.setCustomId(customId)
        }
        completion(nil)
    }

    @objc public func setNextBundle(_ options: LiveUpdateSetNextBundleOptions, completion: @escaping (Error?) -> Void) {
        let bundleId = options.getBundleId()
        if let bundleId = bundleId {
            if hasBundleById(bundleId) {
                setNextBundleById(bundleId)
            } else {
                completion(LiveUpdateError.bundleNotFound)
                return
            }
        } else {
            reset()
        }
        completion(nil)
    }

    @objc public func sync(_ options: LiveUpdateSyncOptions) async throws -> LiveUpdateSyncResult {
        if syncInProgress {
            throw LiveUpdateError.syncInProgress
        }
        syncInProgress = true
        defer { syncInProgress = false }

        let channel = options.getChannel()
        let fetchLatestBundleOptions = LiveUpdateFetchLatestBundleOptions(channel: channel)
        guard let response = try await fetchLatestBundle(fetchLatestBundleOptions) else {
            NSLog("[\(LiveUpdatePlugin.tag)] No update available.")
            return LiveUpdateSyncResult(nextBundleId: nil)
        }
        let artifactType = response.artifactType
        let latestBundleId = response.bundleId
        let checksum = response.checksum
        let signature = response.signature
        let downloadUrl = response.url
        if isBlockedBundleId(latestBundleId) {
            NSLog("[\(LiveUpdatePlugin.tag)] Bundle is blocked and will not be downloaded.")
            return LiveUpdateSyncResult(nextBundleId: nil)
        }
        if hasBundleById(latestBundleId) {
            var nextBundleId: String?
            let currentBundleId = getCurrentBundleId()
            if latestBundleId != currentBundleId {
                setNextBundleById(latestBundleId)
                nextBundleId = latestBundleId
            }
            return LiveUpdateSyncResult(nextBundleId: nextBundleId)
        }
        if artifactType == .manifest {
            try await downloadBundleOfTypeManifest(bundleId: latestBundleId, url: downloadUrl)
        } else {
            try await downloadBundleOfTypeZip(bundleId: latestBundleId, checksum: checksum, signature: signature, url: downloadUrl)
        }
        setNextBundleById(latestBundleId)
        return LiveUpdateSyncResult(nextBundleId: latestBundleId)
    }

    // MARK: - Private helpers

    private func addBundle(bundleId: String, directory: URL) throws {
        guard let indexHtmlFile = searchIndexHtmlFile(url: directory) else {
            throw LiveUpdateError.bundleIndexHtmlMissing
        }
        createBundlesDirectory()
        let bundlePath = buildBundlePathFor(bundleId: bundleId)
        try FileManager.default.moveItem(atPath: indexHtmlFile.deletingLastPathComponent().path, toPath: bundlePath)
    }

    private func addBundleOfTypeManifest(bundleId: String, directory: URL) async throws {
        try addBundle(bundleId: bundleId, directory: directory)
    }

    private func addBundleOfTypeZip(bundleId: String, zipFile: URL) async throws {
        let unzippedDirectory = try unzipFile(zipFile: zipFile)
        try addBundle(bundleId: bundleId, directory: unzippedDirectory)
    }

    private func buildBundlePathFor(bundleId: String) -> String {
        return buildBundleURLFor(bundleId: bundleId).path
    }

    private func buildBundleURLFor(bundleId: String) -> URL {
        return libraryDirectoryUrl.appendingPathComponent(bundlesDirectory).appendingPathComponent(bundleId)
    }

    private func copyCurrentBundleFile(fileToCopy: LiveUpdateManifestItem, toDirectory: URL) throws {
        let currentBundleId = getCurrentBundleId()
        let destination = toDirectory.appendingPathComponent(fileToCopy.href)
        let parentDirectory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

        let sourceURL: URL
        if let currentBundleId = currentBundleId {
            sourceURL = buildBundleURLFor(bundleId: currentBundleId).appendingPathComponent(fileToCopy.href)
        } else {
            guard let file = Bundle.main.url(forResource: fileToCopy.href, withExtension: nil, subdirectory: defaultWebAssetDir) else {
                throw LiveUpdateError.unknown
            }
            sourceURL = file
        }

        try FileManager.default.copyItem(at: sourceURL, to: destination)
    }

    private func copyCurrentBundleFilesAndReturnFailures(
        filesToCopy: [LiveUpdateManifestItem],
        toDirectory: URL
    ) -> [LiveUpdateManifestItem] {
        var missingItems = [LiveUpdateManifestItem]()
        for fileToCopy in filesToCopy {
            if !tryCopyCurrentBundleFile(fileToCopy: fileToCopy, toDirectory: toDirectory) {
                NSLog("[\(LiveUpdatePlugin.tag)] Failed to copy file: \(fileToCopy.href)")
                missingItems.append(fileToCopy)
            }
        }
        return missingItems
    }

    private func createBundlesDirectory() {
        let bundlesDirectoryUrl = libraryDirectoryUrl.appendingPathComponent(bundlesDirectory)
        let exists = FileManager.default.fileExists(atPath: bundlesDirectoryUrl.path)
        if !exists {
            do {
                try FileManager.default.createDirectory(at: bundlesDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog("[\(LiveUpdatePlugin.tag)] Failed to create bundles directory.")
            }
        }
    }

    private func createTemporaryDirectory() throws -> URL {
        let temporaryDirectory = cachesDirectoryUrl.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        return temporaryDirectory
    }

    private func deleteBundleById(_ bundleId: String) throws {
        let path = buildBundlePathFor(bundleId: bundleId)
        try FileManager.default.removeItem(atPath: path)
        if bundleId == getNextBundleId() {
            setNextBundleById(nil)
        }
    }

    private func deleteUnusedBundles() {
        let bundleIds = getDownloadedBundleIds()
        let currentBundleId = getCurrentBundleId()
        let nextBundleId = getNextBundleId()
        for bundleId in bundleIds where bundleId != currentBundleId && bundleId != nextBundleId {
            do {
                try deleteBundleById(bundleId)
            } catch {
                NSLog("[\(LiveUpdatePlugin.tag)] Failed to delete bundle with id: \(bundleId)")
            }
        }
    }

    private func downloadAndVerifyFile(url: String, file: URL, checksum: String?, signature: String?, callback: ((Progress) -> Void)?) async throws {
        let destination: DownloadRequest.Destination = { _, _ in
            return (file, [.createIntermediateDirectories])
        }
        let urlComponents = URLComponents(string: url)!
        let result = try await httpClient.download(url: urlComponents.asURL(), destination: destination, callback: callback)
        if let error = result.error {
            NSLog("[\(LiveUpdatePlugin.tag)] Failed to download file: \(error)")
            if let urlError = error.underlyingError as? URLError, urlError.code == .timedOut {
                throw urlError
            }
            throw LiveUpdateError.downloadFailed
        }
        guard let response = result.response else {
            throw LiveUpdateError.unknown
        }
        let resolvedChecksum = checksum ?? LiveUpdateHttpClient.getChecksumFromResponse(response: response)
        let resolvedSignature = signature ?? LiveUpdateHttpClient.getSignatureFromResponse(response: response)
        try verifyFile(url: file, checksum: resolvedChecksum, signature: resolvedSignature)
    }

    private func downloadBundleFile(baseUrl: String, href: String, directory: URL, callback: ((Progress) -> Void)?) async throws -> URL {
        let fileURL = directory.appendingPathComponent(href)
        var urlComponents = URLComponents(string: baseUrl)!
        urlComponents.queryItems = [URLQueryItem(name: "href", value: href)]
        let url = urlComponents.string!
        try await downloadAndVerifyFile(url: url, file: fileURL, checksum: nil, signature: nil, callback: callback)
        return fileURL
    }

    private func downloadBundleFiles(url: String, filesToDownload: [LiveUpdateManifestItem], directory: URL, callback: ((Progress) -> Void)?) async throws {
        let totalBytesToDownload = Int64(filesToDownload.map { $0.sizeInBytes }.reduce(0, +))
        actor TotalBytesDownloaded {
            var value: Int64 = 0
            func add(_ amount: Int64) {
                value += amount
            }
        }
        let totalBytesDownloaded = TotalBytesDownloaded()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for fileToDownload in filesToDownload {
                group.addTask {
                    _ = try await self.downloadBundleFile(baseUrl: url, href: fileToDownload.href, directory: directory, callback: { progress in
                        Task {
                            if let callback = callback {
                                let total = await totalBytesDownloaded.value
                                let totalProgress = Progress(totalUnitCount: totalBytesToDownload, completedUnitCount: progress.completedUnitCount + total)
                                callback(totalProgress)
                            }
                        }
                    })
                    if let callback = callback {
                        await totalBytesDownloaded.add(Int64(fileToDownload.sizeInBytes))
                        let total = await totalBytesDownloaded.value
                        let totalProgress = Progress(totalUnitCount: totalBytesToDownload, completedUnitCount: total)
                        callback(totalProgress)
                    }
                }
            }
            try await group.waitForAll()
            if let callback = callback {
                let totalProgress = Progress(totalUnitCount: totalBytesToDownload, completedUnitCount: totalBytesToDownload)
                callback(totalProgress)
            }
        }
    }

    private func downloadBundleOfTypeManifest(bundleId: String, url: String) async throws {
        let temporaryDirectory = try createTemporaryDirectory()
        let latestManifestFile = try await downloadBundleFile(baseUrl: url, href: manifestFileName, directory: temporaryDirectory, callback: nil)
        let latestManifest = try loadManifest(file: latestManifestFile)
        let currentManifest = try loadCurrentManifest()
        var itemsToCopy = [LiveUpdateManifestItem]()
        var itemsToDownload = [LiveUpdateManifestItem]()
        if let currentManifest = currentManifest {
            itemsToCopy.append(contentsOf: LiveUpdateManifest.findDuplicateItems(latestManifest, currentManifest))
            itemsToDownload.append(contentsOf: LiveUpdateManifest.findMissingItems(latestManifest, currentManifest))
        } else {
            itemsToDownload.append(contentsOf: latestManifest.items)
        }
        let missingItems = copyCurrentBundleFilesAndReturnFailures(filesToCopy: itemsToCopy, toDirectory: temporaryDirectory)
        if !missingItems.isEmpty {
            itemsToDownload.append(contentsOf: missingItems)
        }
        try await downloadBundleFiles(url: url, filesToDownload: itemsToDownload, directory: temporaryDirectory, callback: { progress in
            let event = LiveUpdateDownloadBundleProgressEvent(bundleId: bundleId, downloadedBytes: progress.completedUnitCount, totalBytes: progress.totalUnitCount)
            self.notifyDownloadBundleProgressListeners(event)
        })
        try await addBundleOfTypeManifest(bundleId: bundleId, directory: temporaryDirectory)
    }

    private func downloadBundleOfTypeZip(bundleId: String, checksum: String?, signature: String?, url: String) async throws {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let temporaryZipFileUrl = cachesDirectoryUrl.appendingPathComponent(timestamp + ".zip")
        try await downloadAndVerifyFile(url: url, file: temporaryZipFileUrl, checksum: checksum, signature: signature, callback: { progress in
            let event = LiveUpdateDownloadBundleProgressEvent(bundleId: bundleId, downloadedBytes: progress.completedUnitCount, totalBytes: progress.totalUnitCount)
            self.notifyDownloadBundleProgressListeners(event)
        })
        try await addBundleOfTypeZip(bundleId: bundleId, zipFile: temporaryZipFileUrl)
    }

    private func fetchLatestBundle(_ options: LiveUpdateFetchLatestBundleOptions) async throws -> LiveUpdateGetLatestBundleResponse? {
        let channel = options.getChannel() ?? getChannel()
        var parameters = [String: String]()
        parameters["appVersionCode"] = getVersionCode()
        parameters["appVersionName"] = getVersionName()
        parameters["bundleId"] = getCurrentBundleId()
        parameters["channelName"] = channel
        parameters["customId"] = preferences.getCustomId()
        parameters["deviceId"] = getDeviceId()
        parameters["osVersion"] = await UIDevice.current.systemVersion
        parameters["platform"] = "1"
        parameters["pluginVersion"] = LiveUpdatePlugin.version
        parameters["runtime"] = "cordova"
        var urlComponents = URLComponents(string: "https://\(config.serverDomain)/v1/apps/\(getAppId() ?? "")/bundles/latest")!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        let url = try urlComponents.asURL()
        NSLog("[\(LiveUpdatePlugin.tag)] Fetching latest bundle: \(url)")
        let response = try await self.httpClient.request(url: url, type: LiveUpdateGetLatestBundleResponse.self)
        if let data = response.data {
            NSLog("[\(LiveUpdatePlugin.tag)] Latest bundle response: \(String(decoding: data, as: UTF8.self))")
        }
        if let error = response.error {
            if let urlError = error.underlyingError as? URLError, urlError.code == .timedOut {
                throw urlError
            }
            return nil
        }
        return response.value
    }

    private func getDownloadedBundleIds() -> [String] {
        let url = libraryDirectoryUrl.appendingPathComponent(bundlesDirectory)
        do {
            guard FileManager.default.fileExists(atPath: url.path) else { return [] }
            return try FileManager.default.contentsOfDirectory(atPath: url.path)
        } catch {
            return []
        }
    }

    private func getAppId() -> String? {
        if let appId = preferences.getAppId() {
            return appId
        }
        return config.appId
    }

    private func getChannel() -> String? {
        var channel: String?
        if let defaultChannel = config.defaultChannel {
            channel = defaultChannel
        }
        if let nativeChannel = getNativeChannel() {
            channel = nativeChannel
        }
        if let preferencesChannel = preferences.getChannel() {
            channel = preferencesChannel
        }
        return channel
    }

    private func getNativeChannel() -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "CapawesomeLiveUpdateDefaultChannel") as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func getChecksumForFile(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let nextChunk = handle.readData(ofLength: 2048)
            guard !nextChunk.isEmpty else { return false }
            hasher.update(data: nextChunk)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    /// - Returns: The current bundle ID or `nil` if the default bundle is in use.
    private func getCurrentBundleId() -> String? {
        guard let dir = schemeHandler.activeBundleDir else {
            return nil
        }
        return dir.lastPathComponent
    }

    private func getDeviceId() -> String {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        return deviceId.lowercased()
    }

    /// - Returns: The next bundle ID or `nil` if the default bundle will be used.
    private func getNextBundleId() -> String? {
        return preferences.getNextBundleId()
    }

    private func getPreviousBundleId() -> String? {
        return preferences.getPreviousBundleId()
    }

    private func getVersionCode() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    private func getVersionName() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private func hasBundleById(_ bundleId: String) -> Bool {
        return FileManager.default.fileExists(atPath: buildBundlePathFor(bundleId: bundleId))
    }

    private func loadCurrentManifest() throws -> LiveUpdateManifest? {
        if let currentBundleId = getCurrentBundleId() {
            let manifestFileUrl = buildBundleURLFor(bundleId: currentBundleId).appendingPathComponent(manifestFileName)
            if FileManager.default.fileExists(atPath: manifestFileUrl.path) {
                return try loadManifest(file: manifestFileUrl)
            }
            return nil
        } else {
            let files = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: defaultWebAssetDir) ?? []
            if let manifestFileUrl = files.first(where: { $0.lastPathComponent == manifestFileName }) {
                return try loadManifest(file: manifestFileUrl)
            }
            return nil
        }
    }

    private func loadManifest(file: URL) throws -> LiveUpdateManifest {
        let data = try Data(contentsOf: file)
        let items = try JSONDecoder().decode([LiveUpdateManifestItem].self, from: data)
        return LiveUpdateManifest(items: items)
    }

    private func notifyDownloadBundleProgressListeners(_ event: LiveUpdateDownloadBundleProgressEvent) {
        plugin.notifyDownloadBundleProgressListeners(event)
    }

    private func performAutoUpdate() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if lastAutoUpdateCheckTimestamp > 0 && (now - lastAutoUpdateCheckTimestamp) < autoUpdateIntervalMs {
            NSLog("[\(LiveUpdatePlugin.tag)] Auto-update skipped. Last check was less than 15 minutes ago.")
            return
        }

        if (getAppId() ?? "").isEmpty {
            NSLog("[\(LiveUpdatePlugin.tag)] Auto-update skipped. appId is not configured.")
            return
        }

        lastAutoUpdateCheckTimestamp = now

        Task {
            do {
                NSLog("[\(LiveUpdatePlugin.tag)] Auto-update started.")
                _ = try await sync(LiveUpdateSyncOptions(channel: nil))
                NSLog("[\(LiveUpdatePlugin.tag)] Auto-update completed successfully.")
            } catch {
                NSLog("[\(LiveUpdatePlugin.tag)] Auto-update failed: \(error.localizedDescription)")
            }
        }
    }

    private func rollback() {
        rollbackPerformed = true
        let currentBundleId = getCurrentBundleId()
        setPreviousBundleId(bundleId: currentBundleId)
        if currentBundleId != nil {
            NSLog("[\(LiveUpdatePlugin.tag)] App is not ready. Rolling back to default bundle.")
            setNextBundleById(nil)
            setCurrentBundleById(nil)
        } else {
            NSLog("[\(LiveUpdatePlugin.tag)] App is not ready. Default bundle is already in use.")
        }
    }

    private func searchIndexHtmlFile(url: URL) -> URL? {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            if directoryContents.isEmpty {
                return nil
            }
            let fileNames = directoryContents.map { $0.lastPathComponent }
            if fileNames.contains("index.html") {
                return url.appendingPathComponent("index.html")
            }
            for fileUrl in directoryContents {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: fileUrl.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    if let indexHtmlFile = searchIndexHtmlFile(url: fileUrl) {
                        return indexHtmlFile
                    }
                }
            }
        } catch {
            NSLog("[\(LiveUpdatePlugin.tag)] Failed to search index.html file: \(error.localizedDescription)")
        }
        return nil
    }

    /// - Parameter bundleId: The bundle ID to set as the current bundle. If `nil`, the default bundle will be used.
    private func setCurrentBundleById(_ bundleId: String?) {
        if let bundleId = bundleId {
            schemeHandler.activeBundleDir = buildBundleURLFor(bundleId: bundleId)
        } else {
            schemeHandler.activeBundleDir = nil
        }
        plugin.reloadWebView()
    }

    /// - Parameter bundleId: The bundle ID to set as the next bundle. If `nil`, the default bundle will be used.
    private func setNextBundleById(_ bundleId: String?) {
        preferences.setNextBundleId(bundleId)
        notifyNextBundleSetListeners(bundleId)
    }

    private func notifyNextBundleSetListeners(_ bundleId: String?) {
        let event = LiveUpdateNextBundleSetEvent(bundleId: bundleId)
        plugin.notifyNextBundleSetListeners(event)
    }

    private func addBlockedBundleId(_ bundleId: String) {
        var blockedList: [String] = []
        if let blockedIds = preferences.getBlockedBundleIds(), !blockedIds.isEmpty {
            blockedList = blockedIds.split(separator: ",").map(String.init)
        }
        if blockedList.contains(bundleId) {
            return
        }
        if blockedList.count >= 100 {
            blockedList.removeFirst()
        }
        blockedList.append(bundleId)
        preferences.setBlockedBundleIds(blockedList.joined(separator: ","))
        NSLog("[\(LiveUpdatePlugin.tag)] Bundle blocked: \(bundleId)")
    }

    private func isBlockedBundleId(_ bundleId: String) -> Bool {
        guard let blockedIds = preferences.getBlockedBundleIds(), !blockedIds.isEmpty else {
            return false
        }
        return blockedIds.split(separator: ",").map(String.init).contains(bundleId)
    }

    private func checkAndResetConfigIfVersionChanged() {
        let currentVersionCode = getVersionCode()
        let currentVersionName = getVersionName()
        let lastVersionCode = preferences.getLastVersionCode()
        let lastVersionName = preferences.getLastVersionName()

        if lastVersionCode == nil || lastVersionName == nil || lastVersionCode != currentVersionCode || lastVersionName != currentVersionName {
            NSLog(
                "[\(LiveUpdatePlugin.tag)] App version changed (last: \(lastVersionName ?? "nil")/\(lastVersionCode ?? "nil"), current: \(currentVersionName)/\(currentVersionCode)), resetting config."
            )
            resetConfig()
            preferences.setLastVersionCode(currentVersionCode)
            preferences.setLastVersionName(currentVersionName)
        }
    }

    private func setPreviousBundleId(bundleId: String?) {
        preferences.setPreviousBundleId(bundleId)
    }

    private func startRollbackTimer() {
        guard config.readyTimeout > 0 else {
            return
        }
        stopRollbackTimer()
        rollbackDispatchWorkItem = DispatchWorkItem { [weak self] in
            self?.rollback()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.milliseconds(config.readyTimeout), execute: rollbackDispatchWorkItem!)
    }

    private func stopRollbackTimer() {
        rollbackDispatchWorkItem?.cancel()
    }

    private func tryCopyCurrentBundleFile(fileToCopy: LiveUpdateManifestItem, toDirectory: URL) -> Bool {
        do {
            try copyCurrentBundleFile(fileToCopy: fileToCopy, toDirectory: toDirectory)
            return true
        } catch {
            return false
        }
    }

    private func unzipFile(zipFile: URL) throws -> URL {
        let destinationDirectory = zipFile.deletingPathExtension()
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.unzipItem(at: zipFile, to: destinationDirectory)
        return destinationDirectory
    }

    private func verifyFile(url: URL, checksum: String?, signature: String?) throws {
        if let publicKey = config.publicKey {
            guard let signature = signature else {
                throw LiveUpdateError.signatureMissing
            }
            let verified: Bool
            do {
                verified = try verifySignatureForFile(url: url, signature: signature, publicKey: publicKey)
            } catch {
                throw LiveUpdateError.signatureVerificationFailed
            }
            if !verified {
                throw LiveUpdateError.signatureVerificationFailed
            }
        } else if let expectedChecksum = checksum {
            let receivedChecksum: String
            do {
                receivedChecksum = try getChecksumForFile(url: url)
            } catch {
                throw LiveUpdateError.checksumCalculationFailed
            }
            if receivedChecksum != expectedChecksum {
                throw LiveUpdateError.checksumMismatch
            }
        }
    }

    private func verifySignatureForFile(url: URL, signature: String, publicKey: String) throws -> Bool {
        let publicKeyAsBase64 = publicKey
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
        guard let publicKeyData = Data(base64Encoded: publicKeyAsBase64) else {
            NSLog("[\(LiveUpdatePlugin.tag)] Failed to decode public key.")
            return false
        }
        let publicKeyAttributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: 2048,
            kSecReturnPersistentRef: true
        ]
        var secKeyCreateWithDataError: Unmanaged<CFError>?
        guard let secPublicKey = SecKeyCreateWithData(publicKeyData as CFData, publicKeyAttributes as CFDictionary, &secKeyCreateWithDataError) else {
            if let error = secKeyCreateWithDataError?.takeRetainedValue() {
                NSLog("[\(LiveUpdatePlugin.tag)] Failed to create public key: \(error)")
            }
            return false
        }
        guard let signatureData = Data(base64Encoded: signature) else {
            NSLog("[\(LiveUpdatePlugin.tag)] Failed to decode signature.")
            return false
        }

        // SHA256 digest of file contents
        var digestContext = CC_SHA256_CTX()
        CC_SHA256_Init(&digestContext)
        let handle = try FileHandle(forReadingFrom: url)
        while autoreleasepool(invoking: {
            let nextChunk = handle.readData(ofLength: 2048)
            guard !nextChunk.isEmpty else { return false }
            nextChunk.withUnsafeBytes {
                _ = CC_SHA256_Update(&digestContext, $0.baseAddress, CC_LONG(nextChunk.count))
            }
            return true
        }) {}
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes {
            _ = CC_SHA256_Final($0.bindMemory(to: UInt8.self).baseAddress, &digestContext)
        }

        var secKeyVerifySignatureError: Unmanaged<CFError>?
        let signatureAlgorithm = SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA256
        let verificationResult = SecKeyVerifySignature(secPublicKey, signatureAlgorithm, digest as CFData, signatureData as CFData, &secKeyVerifySignatureError)
        if let error = secKeyVerifySignatureError?.takeRetainedValue() {
            NSLog("[\(LiveUpdatePlugin.tag)] Failed to verify signature: \(error)")
        }
        return verificationResult
    }
}

extension Progress {
    convenience init(totalUnitCount: Int64, completedUnitCount: Int64) {
        self.init(totalUnitCount: totalUnitCount)
        self.completedUnitCount = completedUnitCount
    }
}
