import Foundation
import CryptoKit
import ZIPFoundation
import Alamofire
import CommonCrypto
import UIKit

// swiftlint:disable type_body_length
@objc public class LiveUpdate: NSObject {
    private static let downloadsDirectoryUrl = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent("capawesome_live_update_downloads")
    /// Deletes the leftovers of downloads that a process kill interrupted. Runs once per process and
    /// blocks concurrent initializers until it is done, so no other instance can have a download in flight.
    private static let interruptedDownloadsDeleted: Void = {
        try? FileManager.default.removeItem(at: downloadsDirectoryUrl)
    }()
    /// The wait after a 429 or a 503 per app id, from the answer until the wait ends.
    /// Kept in memory only, so a restart of the app always checks.
    private static var checkWaits = [String: DateInterval]()
    /// Guards `checkWaits`: checks can run at the same time.
    private static let checkWaitsLock = NSLock()

    private let autoUpdateIntervalMs: Int64 = 15 * 60 * 1000 // 15 minutes
    private let bundlesDirectory = "NoCloud/capawesome_live_update_bundles" // DO NOT CHANGE!
    private let config: LiveUpdateConfig
    private let defaultWebAssetDir = "www" // Cordova builds place web assets under "www/" inside the app bundle.
    private let httpClient: LiveUpdateHttpClient
    private let libraryDirectoryUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    private let manifestFileName = "capawesome-live-update-manifest.json" // DO NOT CHANGE!
    private let plugin: LiveUpdatePlugin
    private let preferences: LiveUpdatePreferences
    private let schemeHandler: LiveUpdateSchemeHandler

    /// Like all state of the rollback timer, only used on the main thread, where Cordova runs every plugin call.
    private var isAppInBackground = false
    /// Milliseconds left on the rollback timer while it is paused in the background.
    private var remainingRollbackTimeout: Int?
    private var rollbackDeadline: DispatchTime?
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

        // Check version and reset config (and the next bundle) if the native
        // app version changed. This must run before promoting the next bundle
        // below so that a stale, now-incompatible bundle is not activated.
        checkAndResetConfigIfVersionChanged()

        // Promote the persisted next bundle to active for this session. This
        // matches Capacitor's launch-time behavior where the persisted next
        // path becomes the current server base path on each cold start.
        if let nextBundleId = preferences.getNextBundleId(), hasBundleById(nextBundleId) {
            schemeHandler.activeBundleDir = buildBundleURLFor(bundleId: nextBundleId)
        }

        // Set the device ID on the HTTP client (after any potential config reset)
        self.httpClient.setDeviceId(getDeviceId())

        _ = Self.interruptedDownloadsDeleted

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
        if hasBundleById(options.getBundleId()) {
            throw LiveUpdateError.bundleAlreadyExists
        }
        try await downloadBundleAndRecordFailure(options)
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
        let response = try await self.httpClient.requestWithDeviceId(url: url, type: [LiveUpdateGetChannelsResponseItem].self)
        if let error = response.error {
            if response.response?.statusCode == 401 {
                throw LiveUpdateError.channelDiscoveryNotEnabled
            }
            if case .sessionTaskFailed(let taskError) = error {
                try handleRequestFailure(taskError)
            }
            throw error
        }
        let items = response.value ?? []
        let channels = items.map { LiveUpdateChannelResult(id: $0.id, name: $0.name) }
        return LiveUpdateFetchChannelsResult(channels: channels)
    }

    @objc public func fetchLatestBundle(_ options: LiveUpdateFetchLatestBundleOptions) async throws -> LiveUpdateFetchLatestBundleResult {
        let response = try await fetchCheck(options)
        return LiveUpdateFetchLatestBundleResult(response)
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

    @objc public func handleAppDidEnterBackground() {
        isAppInBackground = true
        pauseRollbackTimer()
    }

    @objc public func handleAppWillEnterForeground() {
        isAppInBackground = false
        resumeRollbackTimer()
        if config.autoUpdateStrategy == "background" {
            performAutoUpdate()
        }
    }

    @objc public func ready(completion: @escaping (LiveUpdateResult?, Error?) -> Void) {
        NSLog("%@", "[\(LiveUpdatePlugin.tag)] App is ready.")
        if config.readyTimeout <= 0 {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Ready timeout is set to 0. Automatic rollback is disabled.")
        }
        stopRollbackTimer()
        if config.autoDeleteBundles {
            deleteUnusedBundles()
        }
        let currentBundleId = getCurrentBundleId()
        let previousBundleId = getPreviousBundleId()
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
        preferences.setCustomId(options.getCustomId())
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

        let response = try await fetchCheck(LiveUpdateFetchLatestBundleOptions(channel: options.getChannel()))
        return try await handleSyncCheckResponse(response)
    }

    // MARK: - Private helpers

    private func addBundle(bundleId: String, directory: URL) throws {
        guard let indexHtmlFile = searchIndexHtmlFile(url: directory) else {
            throw LiveUpdateError.bundleIndexHtmlMissing
        }
        createBundlesDirectory()
        let bundlePath = buildBundlePathFor(bundleId: bundleId)
        do {
            try FileManager.default.moveItem(atPath: indexHtmlFile.deletingLastPathComponent().path, toPath: bundlePath)
        } catch where hasBundleById(bundleId) {
            // A concurrent download of the same bundle was installed first
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Bundle already installed: \(bundleId)")
        }
    }

    private func addBundleOfTypeManifest(bundleId: String, directory: URL) async throws {
        try addBundle(bundleId: bundleId, directory: directory)
    }

    private func addBundleOfTypeZip(bundleId: String, zipFile: URL) async throws {
        let unzippedDirectory = try unzipDownloadedBundle(zipFile: zipFile)
        try addBundle(bundleId: bundleId, directory: unzippedDirectory)
    }

    private func buildBundlePathFor(bundleId: String) -> String {
        return buildBundleURLFor(bundleId: bundleId).path
    }

    private func buildBundleURLFor(bundleId: String) -> URL {
        return libraryDirectoryUrl.appendingPathComponent(bundlesDirectory).appendingPathComponent(bundleId)
    }

    private func buildCheckUrl(appId: String) throws -> URL {
        return try "https://\(config.serverDomain)/v1/live-updates/apps/\(appId)/checks".asURL()
    }

    private func buildCreateCheckRequest(_ options: LiveUpdateFetchLatestBundleOptions, pendingFailure: LiveUpdateFailure?) async -> LiveUpdateCreateCheckRequest {
        let osVersion = await UIDevice.current.systemVersion
        return LiveUpdateCreateCheckRequest(
            appVersionCode: getVersionCode(),
            appVersionName: getVersionName(),
            bundleId: getCurrentBundleId(),
            channelName: options.getChannel() ?? getChannel(),
            customId: preferences.getCustomId(),
            deviceId: getDeviceId(),
            failure: pendingFailure.map { LiveUpdateCreateCheckRequest.Failure(bundleId: $0.bundleId, reason: $0.reason) },
            osVersion: osVersion,
            platform: "ios",
            pluginVersion: LiveUpdatePlugin.version,
            runtime: "cordova"
        )
    }

    private func buildDownloadDestination(file: URL) -> DownloadRequest.Destination {
        return { _, _ in
            // `removePreviousFile` ensures that a leftover file from a failed attempt does not fail the download
            return (file, [.createIntermediateDirectories, .removePreviousFile])
        }
    }

    private func buildDownloadProgressCallback(bundleId: String) -> (Progress) -> Void {
        return { progress in
            let event = LiveUpdateDownloadBundleProgressEvent(bundleId: bundleId, downloadedBytes: progress.completedUnitCount, totalBytes: progress.totalUnitCount)
            self.notifyDownloadBundleProgressListeners(event)
        }
    }

    private func buildDownloadsDirectoryUrl() -> URL {
        return Self.downloadsDirectoryUrl
    }

    private func buildUrl(_ text: String) throws -> URL {
        guard let urlComponents = URLComponents(string: text) else {
            throw AFError.invalidURL(url: text)
        }
        return try urlComponents.asURL()
    }

    private func copyCurrentBundleFile(sourceHref: String, destination: URL) throws {
        let currentBundleId = getCurrentBundleId()
        let parentDirectory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

        let sourceURL: URL
        if let currentBundleId = currentBundleId {
            sourceURL = buildBundleURLFor(bundleId: currentBundleId).appendingPathComponent(sourceHref)
        } else {
            guard let file = Bundle.main.url(forResource: sourceHref, withExtension: nil, subdirectory: defaultWebAssetDir) else {
                throw LiveUpdateError.unknown
            }
            sourceURL = file
        }

        try FileManager.default.copyItem(at: sourceURL, to: destination)
    }

    /// A file is copied from the first path of the current bundle with the same checksum. A file that cannot be copied is downloaded.
    /// - Returns: The files of the new manifest that must be downloaded, in the order of the new manifest.
    private func copyUnchangedFilesAndListFilesToDownload(_ latestManifest: LiveUpdateManifest, directory: URL) -> [LiveUpdateManifestItem] {
        let currentHrefsByChecksum = tryLoadCurrentManifest()?.mapFirstHrefsByChecksum() ?? [:]
        var itemsToDownload = [LiveUpdateManifestItem]()
        for item in latestManifest.items {
            let destination = directory.appendingPathComponent(item.href)
            if let sourceHref = currentHrefsByChecksum[item.checksum], tryCopyCurrentBundleFile(sourceHref: sourceHref, destination: destination) {
                continue
            }
            itemsToDownload.append(item)
        }
        return itemsToDownload
    }

    private func createBundlesDirectory() {
        let bundlesDirectoryUrl = libraryDirectoryUrl.appendingPathComponent(bundlesDirectory)
        let exists = FileManager.default.fileExists(atPath: bundlesDirectoryUrl.path)
        if !exists {
            do {
                try FileManager.default.createDirectory(at: bundlesDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to create bundles directory.")
            }
        }
    }

    private func createTemporaryDownloadDirectory() throws -> URL {
        let temporaryDirectory = buildDownloadsDirectoryUrl().appendingPathComponent(UUID().uuidString)
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
                NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to delete bundle with id: \(bundleId)")
            }
        }
    }

    private func downloadAndVerifyFile(url: URL, file: URL, checksum: String?, signature: String?, callback: ((Progress) -> Void)?) async throws {
        let result = await httpClient.downloadWithDeviceId(url: url, destination: buildDownloadDestination(file: file), callback: callback)
        let response = try requireSuccessfulDownloadResponse(result)
        let checksum = checksum ?? LiveUpdateHttpClient.getChecksumFromResponse(response: response)
        let signature = signature ?? LiveUpdateHttpClient.getSignatureFromResponse(response: response)
        try verifyFile(url: file, checksum: checksum, signature: signature)
    }

    /// Records a failed download as the pending failure of the configured app, so that the next check reports it.
    private func downloadBundleAndRecordFailure(_ options: LiveUpdateDownloadBundleOptions) async throws {
        do {
            if options.getArtifactType() == .manifest {
                try await downloadBundleOfTypeManifest(options)
            } else {
                try await downloadBundleOfTypeZip(options)
            }
        } catch {
            if let appId = getAppId(), let reason = LiveUpdateFailureReason(error: error) {
                preferences.trySetPendingFailure(LiveUpdateFailure(appId: appId, bundleId: options.getBundleId(), reason: reason))
            }
            throw error
        }
    }

    private func downloadBundleFile(baseUrl: String, href: String, directory: URL, callback: ((Progress) -> Void)?) async throws -> URL {
        let fileURL = directory.appendingPathComponent(href)
        guard var urlComponents = URLComponents(string: baseUrl) else {
            throw AFError.invalidURL(url: baseUrl)
        }
        urlComponents.queryItems = [URLQueryItem(name: "href", value: href)]
        try await downloadAndVerifyFile(url: urlComponents.asURL(), file: fileURL, checksum: nil, signature: nil, callback: callback)
        return fileURL
    }

    private func downloadBundleFiles(
        _ options: LiveUpdateDownloadBundleOptions,
        filesToDownload: [LiveUpdateManifestItem],
        directory: URL,
        callback: ((Progress) -> Void)?
    ) async throws {
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
                    try await self.downloadManifestItem(fileToDownload, options: options, directory: directory, callback: { progress in
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

    private func downloadBundleOfTypeManifest(_ options: LiveUpdateDownloadBundleOptions) async throws {
        // Create a temporary directory that is deleted once the download completed or failed
        let temporaryDirectory = try createTemporaryDownloadDirectory()
        defer { tryDeleteDirectory(temporaryDirectory) }
        let latestManifestFile = try await downloadManifestFile(options, directory: temporaryDirectory)
        guard let latestManifest = try loadManifest(file: latestManifestFile) else {
            throw LiveUpdateError.manifestInvalid
        }
        let filesToDownload = copyUnchangedFilesAndListFilesToDownload(latestManifest, directory: temporaryDirectory)
        let callback = buildDownloadProgressCallback(bundleId: options.getBundleId())
        try await downloadBundleFiles(options, filesToDownload: filesToDownload, directory: temporaryDirectory, callback: callback)
        try await addBundleOfTypeManifest(bundleId: options.getBundleId(), directory: temporaryDirectory)
    }

    private func downloadBundleOfTypeZip(_ options: LiveUpdateDownloadBundleOptions) async throws {
        // Create a temporary directory that is deleted once the download completed or failed
        let temporaryDirectory = try createTemporaryDownloadDirectory()
        defer { tryDeleteDirectory(temporaryDirectory) }
        let zipFile = temporaryDirectory.appendingPathComponent("bundle.zip")
        let callback = buildDownloadProgressCallback(bundleId: options.getBundleId())
        if let urlTemplate = options.urlTemplate {
            let url = try urlTemplate.buildFileUrl(checksum: options.requireChecksum())
            try await downloadZipFileWithUrlTemplate(url: url, file: zipFile, callback: callback)
            try verifyFirstFileWithUrlTemplate(zipFile, options: options)
        } else {
            let url = try buildUrl(options.getUrl())
            try await downloadAndVerifyFile(
                url: url,
                file: zipFile,
                checksum: options.getChecksum(),
                signature: options.getSignature(),
                callback: callback
            )
        }
        try await addBundleOfTypeZip(bundleId: options.getBundleId(), zipFile: zipFile)
    }

    /// Downloads without the device id header.
    private func downloadFileWithUrlTemplate(url: String, file: URL, callback: ((Progress) -> Void)?) async throws {
        let destination = buildDownloadDestination(file: file)
        let result = await httpClient.download(url: try buildUrl(url), destination: destination, callback: callback)
        _ = try requireSuccessfulDownloadResponse(result)
    }

    private func downloadManifestFile(_ options: LiveUpdateDownloadBundleOptions, directory: URL) async throws -> URL {
        guard let urlTemplate = options.urlTemplate else {
            return try await downloadBundleFile(baseUrl: options.getUrl(), href: manifestFileName, directory: directory, callback: nil)
        }
        let file = directory.appendingPathComponent(manifestFileName)
        try await downloadFileWithUrlTemplate(url: urlTemplate.buildFileUrl(checksum: options.requireChecksum()), file: file, callback: nil)
        try verifyFirstFileWithUrlTemplate(file, options: options)
        return file
    }

    private func downloadManifestItem(
        _ item: LiveUpdateManifestItem,
        options: LiveUpdateDownloadBundleOptions,
        directory: URL,
        callback: ((Progress) -> Void)?
    ) async throws {
        guard let urlTemplate = options.urlTemplate else {
            _ = try await downloadBundleFile(baseUrl: options.getUrl(), href: item.href, directory: directory, callback: callback)
            return
        }
        let file = directory.appendingPathComponent(item.href)
        try await downloadFileWithUrlTemplate(url: urlTemplate.buildFileUrl(checksum: item.checksum), file: file, callback: callback)
        try verifyChecksum(url: file, expectedChecksum: item.checksum)
    }

    /// Downloads without the device id header and without compression.
    private func downloadZipFileWithUrlTemplate(url: String, file: URL, callback: ((Progress) -> Void)?) async throws {
        let destination = buildDownloadDestination(file: file)
        let result = await httpClient.downloadWithoutCompression(url: try buildUrl(url), destination: destination, callback: callback)
        _ = try requireSuccessfulDownloadResponse(result)
    }

    /// Resolves as "no update" while the server asked to wait.
    private func fetchCheck(_ options: LiveUpdateFetchLatestBundleOptions) async throws -> LiveUpdateCreateCheckResponse {
        let appId = try requireAppId()
        if isCheckWaiting(appId: appId) {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] No update available. No check was made because the server asked to wait.")
            return LiveUpdateCreateCheckResponse.createWithoutUpdate()
        }
        let pendingFailure = getPendingFailure(appId: appId)
        let request = await buildCreateCheckRequest(options, pendingFailure: pendingFailure)
        let url = try buildCheckUrl(appId: appId)
        NSLog("%@", "[\(LiveUpdatePlugin.tag)] Creating check: \(url)")
        let response = try await httpClient.post(url: url, body: request)
        let checkResponse = try parseCheckResponse(response)
        if let retryAfterMs = checkResponse.retryAfterMs {
            startCheckWait(appId: appId, retryAfterMs: retryAfterMs)
        } else if let pendingFailure = pendingFailure {
            // Only a 200 comes without a wait, because every status other than 200, 429 and 503 throws.
            preferences.removeReportedFailure(pendingFailure)
        }
        return checkResponse
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

    private func getPendingFailure(appId: String) -> LiveUpdateFailure? {
        guard let pendingFailure = preferences.getPendingFailure(), pendingFailure.appId == appId else {
            return nil
        }
        return pendingFailure
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

    private func handleRequestFailure(_ error: Error) throws -> Never {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            throw LiveUpdateError.requestFailed(message: LiveUpdatePlugin.errorHttpTimeout)
        }
        throw LiveUpdateError.requestFailed(message: error.localizedDescription)
    }

    private func handleSyncCheckResponse(_ response: LiveUpdateCreateCheckResponse) async throws -> LiveUpdateSyncResult {
        guard response.result == .available, let bundle = response.bundle else {
            return LiveUpdateSyncResult(nextBundleId: nil)
        }
        if isBlockedBundleId(bundle.id) {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Bundle is blocked and will not be downloaded.")
            return LiveUpdateSyncResult(nextBundleId: nil)
        }
        if hasBundleById(bundle.id) {
            if bundle.id == getCurrentBundleId() {
                return LiveUpdateSyncResult(nextBundleId: nil)
            }
            setNextBundleById(bundle.id)
            return LiveUpdateSyncResult(nextBundleId: bundle.id)
        }
        try await downloadBundleAndRecordFailure(LiveUpdateDownloadBundleOptions(bundle: bundle))
        setNextBundleById(bundle.id)
        return LiveUpdateSyncResult(nextBundleId: bundle.id)
    }

    private func hasBundleById(_ bundleId: String) -> Bool {
        return FileManager.default.fileExists(atPath: buildBundlePathFor(bundleId: bundleId))
    }

    private func isCheckWaiting(appId: String) -> Bool {
        Self.checkWaitsLock.lock()
        defer { Self.checkWaitsLock.unlock() }
        guard let checkWait = Self.checkWaits[appId] else {
            return false
        }
        // A clock that was set back to before the answer ends the wait, so that the wait never grows
        let now = Date()
        return now >= checkWait.start && now < checkWait.end
    }

    private func isSignatureValid(url: URL, signature: String, publicKey: String) throws -> Bool {
        let publicKeyAsBase64 = publicKey
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
        guard let publicKeyData = Data(base64Encoded: publicKeyAsBase64) else {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to decode public key.")
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
                NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to create public key: \(error)")
            }
            return false
        }
        guard let signatureData = Data(base64Encoded: signature) else {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to decode signature.")
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
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to verify signature: \(error)")
        }
        return verificationResult
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

    /// - Returns: `nil` if the manifest cannot be used.
    private func loadManifest(file: URL) throws -> LiveUpdateManifest? {
        let data = try Data(contentsOf: file)
        return LiveUpdateManifest.parse(data)
    }

    private func logNoUpdateReason(_ response: LiveUpdateCreateCheckResponse, statusCode: Int) {
        if statusCode != 200 {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] No update available. The server answered with status \(statusCode).")
        } else if response.result == .skipped {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] No update available. The check was skipped with the reason \(response.reason ?? "null").")
        } else if response.result == .upToDate {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] The app is up to date.")
        } else {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] No update available.")
        }
    }

    private func notifyDownloadBundleProgressListeners(_ event: LiveUpdateDownloadBundleProgressEvent) {
        // The progress cannot be computed without a positive total
        guard event.totalBytes > 0 else {
            return
        }
        plugin.notifyDownloadBundleProgressListeners(event)
    }

    /// Throws if the server could not be reached or answered with a status other than 200, 429 and 503.
    private func parseCheckResponse(_ response: AFDataResponse<Data?>) throws -> LiveUpdateCreateCheckResponse {
        let body = response.data.flatMap { String(bytes: $0, encoding: .utf8) }
        if let body = body {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Check response: \(body)")
        }
        // A transfer that broke after the headers arrived is a failed request, not an answer.
        if case .sessionTaskFailed(let taskError)? = response.error {
            try handleRequestFailure(taskError)
        }
        guard let httpResponse = response.response else {
            let error: Error = response.error.map { $0.underlyingError ?? $0 } ?? LiveUpdateError.unknown
            throw error
        }
        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
        let checkResponse = try LiveUpdateCreateCheckResponse.parse(statusCode: httpResponse.statusCode, retryAfter: retryAfter, body: body)
        if checkResponse.result != .available {
            logNoUpdateReason(checkResponse, statusCode: httpResponse.statusCode)
        }
        return checkResponse
    }

    private func pauseRollbackTimer() {
        guard let deadline = rollbackDeadline else {
            return
        }
        rollbackDispatchWorkItem?.cancel()
        rollbackDispatchWorkItem = nil
        rollbackDeadline = nil
        let now = DispatchTime.now()
        remainingRollbackTimeout = deadline > now ? Int((deadline.uptimeNanoseconds - now.uptimeNanoseconds) / 1_000_000) : 0
    }

    private func performAutoUpdate() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if lastAutoUpdateCheckTimestamp > 0 && (now - lastAutoUpdateCheckTimestamp) < autoUpdateIntervalMs {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Auto-update skipped. Last check was less than 15 minutes ago.")
            return
        }

        if (getAppId() ?? "").isEmpty {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Auto-update skipped. appId is not configured.")
            return
        }

        lastAutoUpdateCheckTimestamp = now

        Task {
            do {
                NSLog("%@", "[\(LiveUpdatePlugin.tag)] Auto-update started.")
                _ = try await sync(LiveUpdateSyncOptions(channel: nil))
                NSLog("%@", "[\(LiveUpdatePlugin.tag)] Auto-update completed successfully.")
            } catch {
                NSLog("%@", "[\(LiveUpdatePlugin.tag)] Auto-update failed: \(error.localizedDescription)")
            }
        }
    }

    private func requireAppId() throws -> String {
        guard let appId = getAppId(), !appId.isEmpty else {
            throw LiveUpdateError.appIdMissing
        }
        return appId
    }

    private func requireSuccessfulDownloadResponse(_ result: AFDownloadResponse<Data>) throws -> HTTPURLResponse {
        if let error = result.error {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to download file: \(error)")
            if case .sessionTaskFailed(let taskError) = error {
                try handleRequestFailure(taskError)
            }
            throw LiveUpdateError.requestFailed(message: LiveUpdatePlugin.errorDownloadFailed)
        }
        guard let response = result.response else {
            throw LiveUpdateError.unknown
        }
        return response
    }

    private func resumeRollbackTimer() {
        guard let remainingRollbackTimeout = remainingRollbackTimeout else {
            return
        }
        self.remainingRollbackTimeout = nil
        scheduleRollback(afterMilliseconds: remainingRollbackTimeout)
    }

    private func rollback() {
        guard let currentBundleId = getCurrentBundleId() else {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] App is not ready. Default bundle is already in use.")
            return
        }
        rollbackPerformed = true
        setPreviousBundleId(bundleId: currentBundleId)
        NSLog("%@", "[\(LiveUpdatePlugin.tag)] App is not ready. Rolling back to default bundle.")
        if let appId = getAppId() {
            preferences.trySetPendingFailure(LiveUpdateFailure(appId: appId, bundleId: currentBundleId, reason: .readinessTimedOut))
        }
        if config.autoBlockRolledBackBundles {
            addBlockedBundleId(currentBundleId)
        }
        setNextBundleById(nil)
        setCurrentBundleById(nil)
    }

    private func scheduleRollback(afterMilliseconds milliseconds: Int) {
        let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(milliseconds)
        let workItem = DispatchWorkItem { [weak self] in
            self?.rollbackDeadline = nil
            self?.rollback()
        }
        rollbackDeadline = deadline
        rollbackDispatchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
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
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to search index.html file: \(error.localizedDescription)")
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
        NSLog("%@", "[\(LiveUpdatePlugin.tag)] Bundle blocked: \(bundleId)")
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
                "%@",
                "[\(LiveUpdatePlugin.tag)] App version changed (last: \(lastVersionName ?? "nil")/\(lastVersionCode ?? "nil"), current: \(currentVersionName)/\(currentVersionCode)), resetting config."
            )
            resetConfig()
            // Reset the next bundle to the built-in one. The previously persisted
            // bundle was built for the old native binary and is no longer
            // compatible. Capacitor gets this for free because its core resets the
            // server base path on a native update; Cordova has no such mechanism,
            // so we must do it ourselves.
            preferences.setNextBundleId(nil)
            preferences.setLastVersionCode(currentVersionCode)
            preferences.setLastVersionName(currentVersionName)
        }
    }

    private func setPreviousBundleId(bundleId: String?) {
        preferences.setPreviousBundleId(bundleId)
    }

    private func startCheckWait(appId: String, retryAfterMs: Int64) {
        Self.checkWaitsLock.lock()
        defer { Self.checkWaitsLock.unlock() }
        Self.checkWaits[appId] = DateInterval(start: Date(), duration: Double(retryAfterMs) / 1000.0)
    }

    /// The timer only counts time in the foreground, because a suspended app cannot call `ready()`.
    private func startRollbackTimer() {
        guard config.readyTimeout > 0 else {
            return
        }
        stopRollbackTimer()
        if isAppInBackground {
            remainingRollbackTimeout = config.readyTimeout
        } else {
            scheduleRollback(afterMilliseconds: config.readyTimeout)
        }
    }

    private func stopRollbackTimer() {
        rollbackDispatchWorkItem?.cancel()
        rollbackDispatchWorkItem = nil
        rollbackDeadline = nil
        remainingRollbackTimeout = nil
    }

    /// - Returns: `true` if the file was copied.
    private func tryCopyCurrentBundleFile(sourceHref: String, destination: URL) -> Bool {
        do {
            try copyCurrentBundleFile(sourceHref: sourceHref, destination: destination)
            return true
        } catch {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to copy file: \(sourceHref)")
            return false
        }
    }

    private func tryDeleteDirectory(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to delete directory: \(url.path)")
        }
    }

    /// - Returns: `nil` if the current bundle has no manifest or its manifest cannot be used, so that every file is downloaded.
    private func tryLoadCurrentManifest() -> LiveUpdateManifest? {
        do {
            return try loadCurrentManifest()
        } catch {
            NSLog("%@", "[\(LiveUpdatePlugin.tag)] Failed to load the current manifest: \(error.localizedDescription)")
            return nil
        }
    }

    private func unzipDownloadedBundle(zipFile: URL) throws -> URL {
        let destinationDirectory = zipFile.deletingLastPathComponent().appendingPathComponent("bundle")
        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.unzipItem(at: zipFile, to: destinationDirectory)
        } catch {
            throw LiveUpdateError.bundleUnzipFailed(underlyingError: error)
        }
        return destinationDirectory
    }

    private func verifyChecksum(url: URL, expectedChecksum: String) throws {
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

    private func verifyFile(url: URL, checksum: String?, signature: String?) throws {
        if let publicKey = config.publicKey {
            try verifySignature(url: url, signature: signature, publicKey: publicKey)
        } else if let expectedChecksum = checksum {
            try verifyChecksum(url: url, expectedChecksum: expectedChecksum)
        }
    }

    /// Verifies the zip file or the manifest of a bundle with a URL template: the checksum always,
    /// and the signature as well if a public key is configured.
    private func verifyFirstFileWithUrlTemplate(_ file: URL, options: LiveUpdateDownloadBundleOptions) throws {
        try verifyChecksum(url: file, expectedChecksum: options.requireChecksum())
        if let publicKey = config.publicKey {
            try verifySignature(url: file, signature: options.getSignature(), publicKey: publicKey)
        }
    }

    private func verifySignature(url: URL, signature: String?, publicKey: String) throws {
        guard let signature = signature else {
            throw LiveUpdateError.signatureMissing
        }
        let verified: Bool
        do {
            verified = try isSignatureValid(url: url, signature: signature, publicKey: publicKey)
        } catch {
            throw LiveUpdateError.signatureVerificationFailed
        }
        if !verified {
            throw LiveUpdateError.signatureVerificationFailed
        }
    }
}

extension Progress {
    convenience init(totalUnitCount: Int64, completedUnitCount: Int64) {
        self.init(totalUnitCount: totalUnitCount)
        self.completedUnitCount = completedUnitCount
    }
}
