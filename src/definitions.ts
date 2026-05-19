// Plugin configuration is set via `<preference>` entries in `config.xml`,
// not via this TypeScript module. The following preferences are supported:
// `APP_ID`, `AUTO_BLOCK_ROLLED_BACK_BUNDLES`, `AUTO_DELETE_BUNDLES`,
// `AUTO_UPDATE_STRATEGY`, `DEFAULT_CHANNEL`, `HTTP_TIMEOUT`, `PUBLIC_KEY`,
// `READY_TIMEOUT`, `SERVER_DOMAIN`. See README for details.

/**
 * Handle returned from `addListener(...)`. Call `remove()` to detach the
 * listener.
 *
 * @since 0.1.0
 */
export interface PluginListenerHandle {
  remove: () => Promise<void>;
}

export interface LiveUpdatePlugin {
  /**
   * Clear all blocked bundles from the blocked list.
   *
   * This removes all bundle identifiers that were automatically blocked
   * due to rollbacks when `autoBlockRolledBackBundles` is enabled.
   *
   * @since 0.1.0
   */
  clearBlockedBundles(): Promise<void>;
  /**
   * Delete a bundle from the app.
   *
   * @since 0.1.0
   */
  deleteBundle(options: DeleteBundleOptions): Promise<void>;
  /**
   * Download a bundle.
   *
   * @since 0.1.0
   */
  downloadBundle(options: DownloadBundleOptions): Promise<void>;
  /**
   * Fetch channels from [Capawesome Cloud](https://capawesome.io/cloud/).
   *
   * This is primarily intended for development and QA purposes.
   * It allows you to retrieve a list of available channels so you can
   * dynamically switch between them using `setChannel(...)`.
   *
   * **Attention**: Only works for apps with public channels enabled.
   * If channels are private, they can still be set using `setChannel(...)`
   * but won't be returned by this method.
   *
   * @since 0.1.0
   */
  fetchChannels(options?: FetchChannelsOptions): Promise<FetchChannelsResult>;
  /**
   * Fetch the latest bundle using the [Capawesome Cloud](https://capawesome.io/cloud/).
   *
   * @since 0.1.0
   */
  fetchLatestBundle(
    options?: FetchLatestBundleOptions,
  ): Promise<FetchLatestBundleResult>;
  /**
   * Get all blocked bundle identifiers.
   *
   * Returns the list of bundle identifiers that were automatically blocked
   * due to rollbacks when `autoBlockRolledBackBundles` is enabled.
   *
   * @since 0.1.0
   */
  getBlockedBundles(): Promise<GetBlockedBundlesResult>;
  /**
   * Get all identifiers of bundles that have been downloaded.
   *
   * @since 0.1.0
   * @deprecated Use `getDownloadedBundles()` instead.
   */
  getBundles(): Promise<GetBundlesResult>;
  /**
   * Get the channel that is used for the update.
   *
   * The channel is resolved in the following order (highest priority first):
   * 1. `setChannel()` (SharedPreferences on Android / UserDefaults on iOS)
   * 2. Native config (`CapawesomeLiveUpdateDefaultChannel` in `Info.plist` on iOS or
   *    `capawesome_live_update_default_channel` in `strings.xml` on Android)
   * 3. The `DEFAULT_CHANNEL` preference in `config.xml`
   *
   * **Note**: The `channel` parameter of `sync()` takes the highest priority
   * but is not persisted and therefore not returned by this method.
   *
   * @since 0.1.0
   */
  getChannel(): Promise<GetChannelResult>;
  /**
   * Get the runtime configuration.
   *
   * Returns the current plugin configuration including any runtime
   * overrides set via `setConfig()`.
   *
   * @since 0.1.0
   */
  getConfig(): Promise<GetConfigResult>;
  /**
   * Get all identifiers of bundles that have been downloaded.
   *
   * @since 0.1.0
   */
  getDownloadedBundles(): Promise<GetDownloadedBundlesResult>;
  /**
   * Get the bundle identifier of the current bundle.
   * The current bundle is the bundle that is currently used by the app.
   *
   * @since 0.1.0
   */
  getCurrentBundle(): Promise<GetCurrentBundleResult>;
  /**
   * Get the custom identifier of the device.
   *
   * @since 0.1.0
   */
  getCustomId(): Promise<GetCustomIdResult>;
  /**
   * Get the unique device identifier.
   *
   * @since 0.1.0
   */
  getDeviceId(): Promise<GetDeviceIdResult>;
  /**
   * Check whether a sync operation is currently in progress.
   *
   * @since 0.1.0
   */
  isSyncing(): Promise<IsSyncingResult>;
  /**
   * Get the bundle identifier of the next bundle.
   * The next bundle is the bundle that will be used after calling `reload()`
   * or restarting the app.
   *
   * @since 0.1.0
   */
  getNextBundle(): Promise<GetNextBundleResult>;
  /**
   * Get the version code of the app.
   *
   * On **Android**, this is the `versionCode` from `PackageInfo`.
   * On **iOS**, this is the `CFBundleVersion` from the `Info.plist` file.
   *
   * @since 0.1.0
   */
  getVersionCode(): Promise<GetVersionCodeResult>;
  /**
   * Get the version name of the app.
   *
   * On **Android**, this is the `versionName` from `PackageInfo`.
   * On **iOS**, this is the `CFBundleShortVersionString` from the `Info.plist` file.
   *
   * @since 0.1.0
   */
  getVersionName(): Promise<GetVersionNameResult>;
  /**
   * Notify the plugin that the app is ready to use and no rollback is needed.
   *
   * **Attention**: This method should be called as soon as the app is ready to use
   * to prevent the app from being reset to the default bundle.
   *
   * @since 0.1.0
   */
  ready(): Promise<ReadyResult>;
  /**
   * Reload the app to apply the new bundle.
   *
   * @since 0.1.0
   */
  reload(): Promise<void>;
  /**
   * Reset the app to the default bundle.
   *
   * Call `reload()` or restart the app to apply the changes.
   *
   * @since 0.1.0
   */
  reset(): Promise<void>;
  /**
   * Reset the runtime configuration to the values from `config.xml`.
   *
   * This clears any runtime configuration set via `setConfig()`.
   * The changes take effect immediately.
   *
   * @since 0.1.0
   */
  resetConfig(): Promise<void>;
  /**
   * Set the channel to use for the update.
   *
   * @since 0.1.0
   */
  setChannel(options: SetChannelOptions): Promise<void>;
  /**
   * Set the runtime configuration.
   *
   * This allows updating plugin configuration options at runtime.
   * The changes are persisted across app restarts and take effect immediately.
   *
   * **Important:** Runtime configuration is automatically reset to default values
   * whenever the native app is updated to a new version. This ensures that
   * configuration from previous versions doesn't persist after an app update.
   *
   * @since 0.1.0
   */
  setConfig(options: SetConfigOptions): Promise<void>;
  /**
   * Set the custom identifier of the device.
   *
   * @since 0.1.0
   */
  setCustomId(options: SetCustomIdOptions): Promise<void>;
  /**
   * Set the next bundle to use for the app.
   *
   * Call `reload()` or restart the app to apply the changes.
   *
   * @since 0.1.0
   */
  setNextBundle(options: SetNextBundleOptions): Promise<void>;
  /**
   * Automatically download and set the latest bundle for the app using the [Capawesome Cloud](https://capawesome.io/cloud/).
   *
   * Call `reload()` or restart the app to apply the changes.
   *
   * @since 0.1.0
   */
  sync(options?: SyncOptions): Promise<SyncResult>;
  /**
   * Listen for the download progress of a bundle.
   *
   * @since 0.1.0
   */
  addListener(
    eventName: 'downloadBundleProgress',
    listenerFunc: DownloadBundleProgressListener,
  ): Promise<PluginListenerHandle>;
  /**
   * Listen for when a bundle is set as the next bundle.
   *
   * This event is triggered whenever a bundle is set to be used on the next app restart,
   * either through automatic updates or manual calls to `setNextBundle()`.
   *
   * @since 0.1.0
   */
  addListener(
    eventName: 'nextBundleSet',
    listenerFunc: NextBundleSetListener,
  ): Promise<PluginListenerHandle>;
  /**
   * Remove all listeners for this plugin.
   *
   * @since 0.1.0
   */
  removeAllListeners(): Promise<void>;
}

/**
 * @since 0.1.0
 */
export interface DeleteBundleOptions {
  /**
   * The unique identifier of the bundle to delete.
   *
   * @since 0.1.0
   * @example '1.0.0'
   */
  bundleId: string;
}

/**
 * @since 0.1.0
 */
export interface DownloadBundleOptions {
  /**
   * The artifact type of the bundle.
   *
   * @since 0.1.0
   * @default 'zip'
   * @example 'manifest'
   */
  artifactType?: 'manifest' | 'zip';
  /**
   * The unique identifier of the bundle.
   *
   * **Attention**: The value `public` is reserved and cannot be used as a bundle identifier.
   *
   * @since 0.1.0
   * @example '1.0.0'
   */
  bundleId: string;
  /**
   * The checksum of the self-hosted bundle as a SHA-256 hash
   * in hex format to verify the integrity of the bundle.
   *
   * **Attention**: Only supported for the `zip` artifact type.
   *
   * @since 0.1.0
   */
  checksum?: string;
  /**
   * The signature of the self-hosted bundle as a signed SHA-256 hash
   * in base64 format to verify the integrity of the bundle.
   *
   * **Attention**: Only supported for the `zip` artifact type.
   *
   * @since 0.1.0
   */
  signature?: string;
  /**
   * The URL of the bundle to download.
   *
   * For the `zip` artifact type, the URL must point to a ZIP file.
   * For the `manifest` artifact type, the URL serves as the base URL
   * to download the individual files. For example, if the URL is
   * `https://example.com/download`, the plugin will download the file
   * with the href `index.html` from `https://example.com/download?href=index.html`.
   *
   * To **verify the integrity** of the file, the server should return
   * a `X-Checksum` header with the SHA-256 hash in hex format.
   *
   * To **verify the signature** of the file, the server should return
   * a `X-Signature` header with the signed SHA-256 hash in base64 format.
   *
   * @since 0.1.0
   * @example 'https://example.com/bundle.zip'
   */
  url: string;
}

/**
 * @since 0.1.0
 */
export interface FetchChannelsOptions {
  /**
   * The maximum number of channels to return.
   *
   * @since 0.1.0
   * @default 50
   */
  limit?: number;
  /**
   * The number of channels to skip.
   *
   * @since 0.1.0
   * @default 0
   */
  offset?: number;
  /**
   * The query to filter channels by name.
   *
   * @since 0.1.0
   */
  query?: string;
}

/**
 * @since 0.1.0
 */
export interface FetchChannelsResult {
  /**
   * The list of channels.
   *
   * @since 0.1.0
   */
  channels: Channel[];
}

/**
 * @since 0.1.0
 */
export interface Channel {
  /**
   * The unique identifier of the channel.
   *
   * @since 0.1.0
   */
  id: string;
  /**
   * The name of the channel.
   *
   * @since 0.1.0
   */
  name: string;
}

/**
 * @since 0.1.0
 */
export interface FetchLatestBundleOptions {
  /**
   * The name of the channel where the latest bundle is fetched from.
   *
   * @since 0.1.0
   */
  channel?: string;
}

/**
 * @since 0.1.0
 */
export interface FetchLatestBundleResult {
  /**
   * The artifact type of the bundle.
   *
   * @since 0.1.0
   */
  artifactType?: 'manifest' | 'zip';
  /**
   * The unique identifier of the latest bundle.
   *
   * On Capawesome Cloud, this is the ID of the app build artifact.
   *
   * If `null`, no bundle is available.
   *
   * @since 0.1.0
   */
  bundleId: string | null;
  /**
   * The checksum of the latest bundle if the bundle is self-hosted.
   *
   * If the bundle is hosted on Capawesome Cloud, the checksum will be
   * returned as response header when downloading the bundle.
   *
   * @since 0.1.0
   */
  checksum?: string;
  /**
   * Custom properties that are associated with the latest bundle.
   *
   * @since 0.1.0
   * @example { "key": "value" }
   */
  customProperties?: { [key: string]: string };
  /**
   * The URL of the latest bundle to download.
   * Pass this URL to the `downloadBundle(...)` method to download the bundle.
   *
   * @since 0.1.0
   */
  downloadUrl?: string;
  /**
   * The signature of the latest bundle if the bundle is self-hosted.
   *
   * If the bundle is hosted on Capawesome Cloud, the signature will be
   * returned as response header when downloading the bundle.
   *
   * @since 0.1.0
   */
  signature?: string;
}

/**
 * @since 0.1.0
 */
export interface GetBundleResult {
  /**
   * The unique identifier of the active bundle.
   *
   * If `null`, the default bundle is being used.
   *
   * @since 0.1.0
   * @example '1.0.0'
   */
  bundleId: string | null;
}

/**
 * @since 0.1.0
 */
export interface GetBlockedBundlesResult {
  /**
   * An array of unique identifiers of all blocked bundles.
   *
   * @since 0.1.0
   */
  bundleIds: string[];
}

/**
 * @since 0.1.0
 */
export interface GetBundlesResult {
  /**
   * An array of unique identifiers of all available bundles.
   *
   * @since 0.1.0
   */
  bundleIds: string[];
}

/**
 * @since 0.1.0
 */
export interface GetDownloadedBundlesResult {
  /**
   * An array of unique identifiers of all downloaded bundles.
   *
   * @since 0.1.0
   */
  bundleIds: string[];
}

/**
 * @since 0.1.0
 */
export interface GetChannelResult {
  /**
   * The channel name.
   *
   * If `null`, the app is using the default channel.
   *
   * @since 0.1.0
   * @example 'production'
   */
  channel: string | null;
}

/**
 * @since 0.1.0
 */
export interface GetConfigResult {
  /**
   * The app ID used to identify the app.
   *
   * If `null`, no app ID is configured.
   *
   * @since 0.1.0
   * @example '6e351b4f-69a7-415e-a057-4567df7ffe94'
   */
  appId: string | null;
  /**
   * The auto-update strategy for live updates.
   *
   * @since 0.1.0
   * @example 'background'
   */
  autoUpdateStrategy: 'none' | 'background';
}

/**
 * @since 0.1.0
 */
export interface GetCurrentBundleResult {
  /**
   * The unique identifier of the current bundle.
   *
   * If `null`, the default bundle is being used.
   *
   * @since 0.1.0
   */
  bundleId: string | null;
}

/**
 * @since 0.1.0
 */
export interface GetDeviceIdResult {
  /**
   * The unique identifier of the device.
   *
   * On iOS, [`identifierForVendor`](https://developer.apple.com/documentation/uikit/uidevice/1620059-identifierforvendor) is used.
   * The value of this property is the same for apps that come from the same vendor running on the same device.
   *
   * @since 0.1.0
   * @example '50d2a548-80b7-4dad-adc7-97c0e79d8a89'
   */
  deviceId: string;
}

/**
 * @since 0.1.0
 */
export interface IsSyncingResult {
  /**
   * Whether a sync operation is currently in progress.
   *
   * @since 0.1.0
   */
  syncing: boolean;
}

/**
 * @since 0.1.0
 */
export interface GetNextBundleResult {
  /**
   * The unique identifier of the next bundle.
   *
   * If `null`, the default bundle is being used.
   *
   * @since 0.1.0
   */
  bundleId: string | null;
}

/**
 * @since 0.1.0
 */
export interface GetVersionCodeResult {
  /**
   * The version code of the app.
   *
   * On **Android**, this is the `versionCode` from `PackageInfo`.
   * On **iOS**, this is the `CFBundleVersion` from the `Info.plist` file.
   *
   * @since 0.1.0
   * @example "1"
   */
  versionCode: string;
}

/**
 * @since 0.1.0
 */
export interface GetVersionNameResult {
  /**
   * The version name of the app.
   *
   * On **Android**, this is the `versionName` from `PackageInfo`.
   * On **iOS**, this is the `CFBundleShortVersionString` from the `Info.plist` file.
   *
   * @since 0.1.0
   * @example "1.0.0"
   */
  versionName: string;
}

/**
 * @since 0.1.0
 */
export interface GetCustomIdResult {
  /**
   * The custom identifier of the device.
   *
   * If `null`, no custom identifier is set.
   *
   * @since 0.1.0
   * @example '50d2a548-80b7-4dad-adc7-97c0e79d8a89'
   */
  customId: string | null;
}

/**
 * @since 0.1.0
 */
export interface ReadyResult {
  /**
   * The identifier of the previous bundle used.
   *
   * If `null`, the default bundle was used.
   *
   * @since 0.1.0
   */
  previousBundleId: string | null;
  /**
   * The identifier of the current bundle used.
   *
   * If `null`, the default bundle is being used.
   *
   * @since 0.1.0
   */
  currentBundleId: string | null;
  /**
   * Whether or not the app was reset to the default bundle.
   *
   * @since 0.1.0
   */
  rollback: boolean;
}

/**
 * @since 0.1.0
 */
export interface SetBundleOptions {
  /**
   * The unique identifier of the bundle to use.
   *
   * @since 0.1.0
   * @example '1.0.0'
   */
  bundleId: string;
}

/**
 * @since 0.1.0
 */
export interface SetChannelOptions {
  /**
   * The channel name.
   *
   * Set `null` to remove the channel.
   *
   * @since 0.1.0
   */
  channel: string | null;
}

/**
 * @since 0.1.0
 */
export interface SetConfigOptions {
  /**
   * The app ID used to identify the app.
   *
   * Set `null` to reset to the value from the `APP_ID` preference in `config.xml`.
   *
   * @since 0.1.0
   * @example '6e351b4f-69a7-415e-a057-4567df7ffe94'
   */
  appId?: string | null;
}

/**
 * @since 0.1.0
 */
export interface SetCustomIdOptions {
  /**
   * The custom identifier of the device.
   *
   * Set `null` to remove the custom identifier.
   *
   * @since 0.1.0
   */
  customId: string | null;
}

/**
 * @since 0.1.0
 */
export interface SetNextBundleOptions {
  /**
   * The unique identifier of the bundle to use.
   *
   * Set `null` to use the default bundle (same as calling `reset()`).
   *
   * @since 0.1.0
   * @example '1.0.0'
   */
  bundleId: string | null;
}

/**
 * @since 0.1.0
 */
export interface SyncOptions {
  /**
   * The name of the channel where the latest bundle is fetched from.
   *
   * @since 0.1.0
   */
  channel?: string;
}

/**
 * @since 0.1.0
 */
export interface SyncResult {
  /**
   * The identifier of the next bundle to use.
   *
   * If `null`, the app is up-to-date and no new bundle is available.
   *
   * @since 0.1.0
   */
  nextBundleId: string | null;
}

/**
 * Listener for the download progress of a bundle.
 *
 * @since 0.1.0
 */
export type DownloadBundleProgressListener = (
  event: DownloadBundleProgressEvent,
) => void;

/**
 * Event that is triggered when the download progress of a bundle changes.
 *
 * @since 0.1.0
 */
export interface DownloadBundleProgressEvent {
  /**
   * The unique identifier of the bundle that is being downloaded.
   *
   * @since 0.1.0
   */
  bundleId: string;
  /**
   * The number of bytes that have been downloaded.
   *
   * @since 0.1.0
   */
  downloadedBytes: number;
  /**
   * The progress of the download in percent as a value between `0` and `1`.
   *
   * @since 0.1.0
   * @example 0.5
   */
  progress: number;
  /**
   * The total number of bytes to download.
   *
   * @since 0.1.0
   */
  totalBytes: number;
}

/**
 * Listener for when a bundle is set as the next bundle.
 *
 * @since 0.1.0
 */
export type NextBundleSetListener = (event: NextBundleSetEvent) => void;

/**
 * Event that is triggered when a bundle is set as the next bundle.
 *
 * @since 0.1.0
 */
export interface NextBundleSetEvent {
  /**
   * The unique identifier of the bundle that is set as the next bundle.
   *
   * If `null`, the default bundle will be used.
   *
   * @since 0.1.0
   * @example '1.0.0'
   */
  bundleId: string | null;
}
