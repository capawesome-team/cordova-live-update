# @capawesome/cordova-live-update

Cordova plugin that allows you to update your app remotely in real-time without requiring users to download a new version from the app store, also known as Over-the-Air (OTA) updates.

This is a Cordova port of [`@capawesome/capacitor-live-update`](https://github.com/capawesome-team/capacitor-plugins/tree/main/packages/live-update) with full API parity. If you are using Capacitor, use the Capacitor plugin instead.

## Features

- 🔋 Supports **Android and iOS**
- ⚡️ Works with **stock Cordova WebView** — does **not** require `cordova-plugin-ionic-webview`
- 📦 **Bundle Management** — download, set, and delete bundles
- ☁️ **Cloud Support** — manage updates via [Capawesome Cloud](https://cloud.capawesome.io/)
- 📺 **Channel Support** — set a channel for the app to manage different versions
- 🔄 **Auto Update** — background update strategy with 15-minute throttle
- 🛟 **Rollback** — automatic revert to the default bundle on failed updates
- 🔁 **Delta Updates** — manifest mode downloads only changed files
- ⚙️ **Runtime Configuration** — update plugin configuration at runtime
- 📡 **Update Lifecycle Events** — track download progress, react to bundle changes, detect reloads
- 🏷️ **Custom Properties** — associate custom key-value metadata with bundles via Capawesome Cloud
- 🔒 **Security** — verify authenticity and integrity of bundles via RSA signature
- 🌐 **Open Source** — MIT licensed

## Newsletter

Stay up to date with the latest news and updates about the Capawesome, Capacitor, and Ionic ecosystem by subscribing to our [Capawesome Newsletter](https://cloud.capawesome.io/newsletter/).

## Compatibility

| Plugin Version | Cordova Android Version | Cordova iOS Version | Status         |
| -------------- | ----------------------- | ------------------- | -------------- |
| 0.1.x          | >=13.0.0                | >=7.0.0             | Active support |

## ⚠️ WebView Scheme Requirement

This plugin replaces files served to the WebView by hooking into Cordova's official plugin extension points (`CordovaPluginPathHandler` on Android, `CDVPluginSchemeHandler` on iOS). These hooks only fire when the WebView is loading via a custom scheme — which is the **default** for modern Cordova:

- **Android (cordova-android ≥10):** loads from `https://localhost/` via `WebViewAssetLoader`. ✅ Supported by default.
- **iOS (cordova-ios ≥6):** loads from `app://localhost/` via `WKURLSchemeHandler`. ✅ Supported by default.

The plugin **will not work** if your app overrides these to use the legacy file scheme:

- ❌ `<preference name="AndroidInsecureFileModeEnabled" value="true" />`
- ❌ `<preference name="Scheme" value="file" />`

If you require these settings, this plugin is not for you.

## Guides

- [Getting Started with Capawesome Cloud Live Updates](https://capawesome.io/cloud/live-updates/setup/)
- [Migrating from Ionic Appflow to Capawesome Cloud](https://capawesome.io/blog/migrating-from-ionic-appflow-to-capawesome-cloud/)

## Installation

Install the plugin by running the following command and follow the platform-specific instructions below:

```bash
cordova plugin add @capawesome/cordova-live-update --variable APP_ID=<your-app-id>
```

### Android

#### Channel

For a **static** default channel, use the [`DEFAULT_CHANNEL`](#plugin-variables) plugin variable — no native config required.

If you are using [Versioned Channels](https://capawesome.io/cloud/live-updates/guides/best-practices/#versioned-channels), the channel value needs to be interpolated from the build's `versionCode`, which can't be expressed via a plugin variable. Use Cordova's `build-extras.gradle` mechanism instead. In your app's `config.xml`, add:

```xml
<platform name="android">
    <resource-file src="build-extras.gradle" target="app/build-extras.gradle"/>
</platform>
```

Then create `build-extras.gradle` next to `config.xml`:

```groovy
android {
    applicationVariants.all { variant ->
        variant.resValue "string", "capawesome_live_update_default_channel", "production-${variant.versionCode}"
    }
}
```

### iOS

#### Channel

For a **static** default channel, use the [`DEFAULT_CHANNEL`](#plugin-variables) plugin variable — no native config required.

If you are using [Versioned Channels](https://capawesome.io/cloud/live-updates/guides/best-practices/#versioned-channels), use Cordova's `<config-file>` mechanism in your app's `config.xml`:

```xml
<platform name="ios">
    <config-file target="*-Info.plist" parent="CapawesomeLiveUpdateDefaultChannel">
        <string>production-$(CURRENT_PROJECT_VERSION)</string>
    </config-file>
</platform>
```

Xcode resolves `$(CURRENT_PROJECT_VERSION)` at build time.

#### Privacy manifest

Starting with [cordova-ios 7.1.0](https://cordova.apache.org/announcements/2024/04/03/cordova-ios-7.1.0.html), the iOS [Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) is configured via a `<privacy-manifest>` element inside the `<platform name="ios">` section of your app's `config.xml`. Add an `NSPrivacyAccessedAPICategoryUserDefaults` entry for this plugin:

```xml
<platform name="ios">
    <privacy-manifest>
        <key>NSPrivacyAccessedAPITypes</key>
        <array>
            <!-- Add this dict entry to the array if the key already exists. -->
            <dict>
                <key>NSPrivacyAccessedAPIType</key>
                <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
                <key>NSPrivacyAccessedAPITypeReasons</key>
                <array>
                    <string>CA92.1</string>
                </array>
            </dict>
        </array>
    </privacy-manifest>
</platform>
```

We recommend to declare [`CA92.1`](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api#4278401) as the reason for accessing the [`UserDefaults`](https://developer.apple.com/documentation/foundation/userdefaults) API.

## Plugin Variables

These map to Cordova `<preference>` entries in `config.xml`. Set them at install time with `--variable`, or edit `config.xml` directly:

| Variable                         | Default                   | Description                                                                                                            |
| -------------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `APP_ID`                         | *(empty)*                 | Capawesome Cloud app ID (a UUID).                                                                                      |
| `DEFAULT_CHANNEL`                | *(empty)*                 | Default channel name. Overridden by native config or `setChannel()`.                                                   |
| `AUTO_UPDATE_STRATEGY`           | `none`                    | `none` or `background`. `background` runs `sync()` on cold start and foreground (15-minute throttle).                  |
| `HTTP_TIMEOUT`                   | `60000`                   | HTTP request timeout in milliseconds.                                                                                  |
| `PUBLIC_KEY`                     | *(empty)*                 | PEM-encoded RSA public key for signature verification. When set, all bundle downloads must include a valid signature.  |
| `READY_TIMEOUT`                  | `0`                       | Milliseconds to wait for `ready()` before automatic rollback. Set to e.g. `10000` to enable rollback. `0` disables it. |
| `SERVER_DOMAIN`                  | `api.cloud.capawesome.io` | Capawesome Cloud API host (no scheme/path).                                                                            |
| `AUTO_DELETE_BUNDLES`            | `false`                   | Whether to delete unused bundles when `ready()` is called.                                                             |
| `AUTO_BLOCK_ROLLED_BACK_BUNDLES` | `false`                   | Whether to block bundles that caused a rollback. No effect if `READY_TIMEOUT=0`.                                       |

### Example

```xml
<plugin name="@capawesome/cordova-live-update" spec="0.1.0">
  <variable name="APP_ID" value="6e351b4f-69a7-415e-a057-4567df7ffe94" />
  <variable name="AUTO_UPDATE_STRATEGY" value="background" />
  <variable name="DEFAULT_CHANNEL" value="production" />
  <variable name="READY_TIMEOUT" value="10000" />
  <variable name="PUBLIC_KEY" value="-----BEGIN PUBLIC KEY-----MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDDodf1SD0OOn6hIlDuKBza0Ed0OqtwyVJwiyjmE9BJaZ7y8ZUfcF+SKmd0l2cDPM45XIg2tAFux5n29uoKyHwSt+6tCi5CJA5Z1/1eZruRRqABLonV77KS3HUtvOgqRLDnKSV89dYZkM++NwmzOPgIF422mvc+VukcVOBfc8/AHQIDAQAB-----END PUBLIC KEY-----" />
</plugin>
```

## Usage

The plugin attaches to `cordova.plugins.LiveUpdate` once `deviceready` fires.

If you use TypeScript, type definitions are available from the npm package:

```ts
import type { LiveUpdatePlugin } from '@capawesome/cordova-live-update';

declare const cordova: { plugins: { LiveUpdate: LiveUpdatePlugin } };
```

```javascript
const { LiveUpdate } = cordova.plugins;

const deleteBundle = async () => {
  await LiveUpdate.deleteBundle({ bundleId: 'my-bundle' });
};

const downloadBundle = async () => {
  await LiveUpdate.downloadBundle({ url: 'https://example.com/1.0.0.zip', bundleId: '1.0.0' });
};

const fetchChannels = async () => {
  const result = await LiveUpdate.fetchChannels();
  return result.channels;
};

const fetchLatestBundle = async () => {
  await LiveUpdate.fetchLatestBundle();
};

const getBundles = async () => {
  const result = await LiveUpdate.getBundles();
  return result.bundleIds;
};

const getChannel = async () => {
  const result = await LiveUpdate.getChannel();
  return result.channel;
};

const getCurrentBundle = async () => {
  const result = await LiveUpdate.getCurrentBundle();
  return result.bundleId;
};

const getCustomId = async () => {
  const result = await LiveUpdate.getCustomId();
  return result.customId;
};

const getDeviceId = async () => {
  const result = await LiveUpdate.getDeviceId();
  return result.deviceId;
};

const getNextBundle = async () => {
  const result = await LiveUpdate.getNextBundle();
  return result.bundleId;
};

const getVersionCode = async () => {
  const result = await LiveUpdate.getVersionCode();
  return result.versionCode;
};

const getVersionName = async () => {
  const result = await LiveUpdate.getVersionName();
  return result.versionName;
};

const ready = async () => {
  const result = await LiveUpdate.ready();
  if (result.currentBundleId) {
    console.log(`The app is now using the bundle with the identifier ${result.currentBundleId}.`);
  }
  if (result.previousBundleId) {
    console.log(`The app was using the bundle with the identifier ${result.previousBundleId}.`);
  }
  if (result.rollback) {
    console.log('The app was reset to the default bundle.');
  }
};

const reload = async () => {
  await LiveUpdate.reload();
};

const reset = async () => {
  await LiveUpdate.reset();
};

const setChannel = async () => {
  await LiveUpdate.setChannel({ channel: 'production-5' });
};

const setCustomId = async () => {
  await LiveUpdate.setCustomId({ customId: 'my-custom-id' });
};

const setNextBundle = async () => {
  await LiveUpdate.setNextBundle({ bundleId: '7f0b9bf2-dff6-4be2-bcac-b068cc5ea756' });
};

const sync = async () => {
  const result = await LiveUpdate.sync({
    channel: 'production-5',
  });
  return result.nextBundleId;
};

const isNewBundleAvailable = async () => {
  const { bundleId: latestBundleId } = await LiveUpdate.fetchLatestBundle({
    channel: 'production-5',
  });
  if (latestBundleId) {
    const { bundleId: currentBundleId } = await LiveUpdate.getCurrentBundle();
    return latestBundleId !== currentBundleId;
  } else {
    return false;
  }
};
```

## API

<docgen-index>

* [`clearBlockedBundles()`](#clearblockedbundles)
* [`deleteBundle(...)`](#deletebundle)
* [`downloadBundle(...)`](#downloadbundle)
* [`fetchChannels(...)`](#fetchchannels)
* [`fetchLatestBundle(...)`](#fetchlatestbundle)
* [`getBlockedBundles()`](#getblockedbundles)
* [`getBundles()`](#getbundles)
* [`getChannel()`](#getchannel)
* [`getConfig()`](#getconfig)
* [`getDownloadedBundles()`](#getdownloadedbundles)
* [`getCurrentBundle()`](#getcurrentbundle)
* [`getCustomId()`](#getcustomid)
* [`getDeviceId()`](#getdeviceid)
* [`isSyncing()`](#issyncing)
* [`getNextBundle()`](#getnextbundle)
* [`getVersionCode()`](#getversioncode)
* [`getVersionName()`](#getversionname)
* [`ready()`](#ready)
* [`reload()`](#reload)
* [`reset()`](#reset)
* [`resetConfig()`](#resetconfig)
* [`setChannel(...)`](#setchannel)
* [`setConfig(...)`](#setconfig)
* [`setCustomId(...)`](#setcustomid)
* [`setNextBundle(...)`](#setnextbundle)
* [`sync(...)`](#sync)
* [`addListener('downloadBundleProgress', ...)`](#addlistenerdownloadbundleprogress-)
* [`addListener('nextBundleSet', ...)`](#addlistenernextbundleset-)
* [`removeAllListeners()`](#removealllisteners)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### clearBlockedBundles()

```typescript
clearBlockedBundles() => any
```

Clear all blocked bundles from the blocked list.

This removes all bundle identifiers that were automatically blocked
due to rollbacks when `autoBlockRolledBackBundles` is enabled.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### deleteBundle(...)

```typescript
deleteBundle(options: DeleteBundleOptions) => any
```

Delete a bundle from the app.

| Param         | Type                                                                |
| ------------- | ------------------------------------------------------------------- |
| **`options`** | <code><a href="#deletebundleoptions">DeleteBundleOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### downloadBundle(...)

```typescript
downloadBundle(options: DownloadBundleOptions) => any
```

Download a bundle.

| Param         | Type                                                                    |
| ------------- | ----------------------------------------------------------------------- |
| **`options`** | <code><a href="#downloadbundleoptions">DownloadBundleOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### fetchChannels(...)

```typescript
fetchChannels(options?: FetchChannelsOptions | undefined) => any
```

Fetch channels from [Capawesome Cloud](https://capawesome.io/cloud/).

This is primarily intended for development and QA purposes.
It allows you to retrieve a list of available channels so you can
dynamically switch between them using `setChannel(...)`.

**Attention**: Only works for apps with public channels enabled.
If channels are private, they can still be set using `setChannel(...)`
but won't be returned by this method.

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code><a href="#fetchchannelsoptions">FetchChannelsOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### fetchLatestBundle(...)

```typescript
fetchLatestBundle(options?: FetchLatestBundleOptions | undefined) => any
```

Fetch the latest bundle using the [Capawesome Cloud](https://capawesome.io/cloud/).

| Param         | Type                                                                          |
| ------------- | ----------------------------------------------------------------------------- |
| **`options`** | <code><a href="#fetchlatestbundleoptions">FetchLatestBundleOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getBlockedBundles()

```typescript
getBlockedBundles() => any
```

Get all blocked bundle identifiers.

Returns the list of bundle identifiers that were automatically blocked
due to rollbacks when `autoBlockRolledBackBundles` is enabled.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getBundles()

```typescript
getBundles() => any
```

Get all identifiers of bundles that have been downloaded.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getChannel()

```typescript
getChannel() => any
```

Get the channel that is used for the update.

The channel is resolved in the following order (highest priority first):
1. `setChannel()` (SharedPreferences on Android / UserDefaults on iOS)
2. Native config (`CapawesomeLiveUpdateDefaultChannel` in `Info.plist` on iOS or
   `capawesome_live_update_default_channel` in `strings.xml` on Android)
3. The `DEFAULT_CHANNEL` preference in `config.xml`

**Note**: The `channel` parameter of `sync()` takes the highest priority
but is not persisted and therefore not returned by this method.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getConfig()

```typescript
getConfig() => any
```

Get the runtime configuration.

Returns the current plugin configuration including any runtime
overrides set via `setConfig()`.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getDownloadedBundles()

```typescript
getDownloadedBundles() => any
```

Get all identifiers of bundles that have been downloaded.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getCurrentBundle()

```typescript
getCurrentBundle() => any
```

Get the bundle identifier of the current bundle.
The current bundle is the bundle that is currently used by the app.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getCustomId()

```typescript
getCustomId() => any
```

Get the custom identifier of the device.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getDeviceId()

```typescript
getDeviceId() => any
```

Get the unique device identifier.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### isSyncing()

```typescript
isSyncing() => any
```

Check whether a sync operation is currently in progress.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getNextBundle()

```typescript
getNextBundle() => any
```

Get the bundle identifier of the next bundle.
The next bundle is the bundle that will be used after calling `reload()`
or restarting the app.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getVersionCode()

```typescript
getVersionCode() => any
```

Get the version code of the app.

On **Android**, this is the `versionCode` from `PackageInfo`.
On **iOS**, this is the `CFBundleVersion` from the `Info.plist` file.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### getVersionName()

```typescript
getVersionName() => any
```

Get the version name of the app.

On **Android**, this is the `versionName` from `PackageInfo`.
On **iOS**, this is the `CFBundleShortVersionString` from the `Info.plist` file.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### ready()

```typescript
ready() => any
```

Notify the plugin that the app is ready to use and no rollback is needed.

**Attention**: This method should be called as soon as the app is ready to use
to prevent the app from being reset to the default bundle.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### reload()

```typescript
reload() => any
```

Reload the app to apply the new bundle.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### reset()

```typescript
reset() => any
```

Reset the app to the default bundle.

Call `reload()` or restart the app to apply the changes.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### resetConfig()

```typescript
resetConfig() => any
```

Reset the runtime configuration to the values from `config.xml`.

This clears any runtime configuration set via `setConfig()`.
The changes take effect immediately.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### setChannel(...)

```typescript
setChannel(options: SetChannelOptions) => any
```

Set the channel to use for the update.

| Param         | Type                                                            |
| ------------- | --------------------------------------------------------------- |
| **`options`** | <code><a href="#setchanneloptions">SetChannelOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### setConfig(...)

```typescript
setConfig(options: SetConfigOptions) => any
```

Set the runtime configuration.

This allows updating plugin configuration options at runtime.
The changes are persisted across app restarts and take effect immediately.

**Important:** Runtime configuration is automatically reset to default values
whenever the native app is updated to a new version. This ensures that
configuration from previous versions doesn't persist after an app update.

| Param         | Type                                                          |
| ------------- | ------------------------------------------------------------- |
| **`options`** | <code><a href="#setconfigoptions">SetConfigOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### setCustomId(...)

```typescript
setCustomId(options: SetCustomIdOptions) => any
```

Set the custom identifier of the device.

| Param         | Type                                                              |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code><a href="#setcustomidoptions">SetCustomIdOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### setNextBundle(...)

```typescript
setNextBundle(options: SetNextBundleOptions) => any
```

Set the next bundle to use for the app.

Call `reload()` or restart the app to apply the changes.

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code><a href="#setnextbundleoptions">SetNextBundleOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### sync(...)

```typescript
sync(options?: SyncOptions | undefined) => any
```

Automatically download and set the latest bundle for the app using the [Capawesome Cloud](https://capawesome.io/cloud/).

Call `reload()` or restart the app to apply the changes.

| Param         | Type                                                |
| ------------- | --------------------------------------------------- |
| **`options`** | <code><a href="#syncoptions">SyncOptions</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### addListener('downloadBundleProgress', ...)

```typescript
addListener(eventName: 'downloadBundleProgress', listenerFunc: DownloadBundleProgressListener) => any
```

Listen for the download progress of a bundle.

| Param              | Type                                                                                      |
| ------------------ | ----------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'downloadBundleProgress'</code>                                                     |
| **`listenerFunc`** | <code><a href="#downloadbundleprogresslistener">DownloadBundleProgressListener</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### addListener('nextBundleSet', ...)

```typescript
addListener(eventName: 'nextBundleSet', listenerFunc: NextBundleSetListener) => any
```

Listen for when a bundle is set as the next bundle.

This event is triggered whenever a bundle is set to be used on the next app restart,
either through automatic updates or manual calls to `setNextBundle()`.

| Param              | Type                                                                    |
| ------------------ | ----------------------------------------------------------------------- |
| **`eventName`**    | <code>'nextBundleSet'</code>                                            |
| **`listenerFunc`** | <code><a href="#nextbundlesetlistener">NextBundleSetListener</a></code> |

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => any
```

Remove all listeners for this plugin.

**Returns:** <code>any</code>

**Since:** 0.1.0

--------------------


### Interfaces


#### DeleteBundleOptions

| Prop           | Type                | Description                                    | Since |
| -------------- | ------------------- | ---------------------------------------------- | ----- |
| **`bundleId`** | <code>string</code> | The unique identifier of the bundle to delete. | 0.1.0 |


#### DownloadBundleOptions

| Prop               | Type                             | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Default            | Since |
| ------------------ | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | ----- |
| **`artifactType`** | <code>'manifest' \| 'zip'</code> | The artifact type of the bundle.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | <code>'zip'</code> | 0.1.0 |
| **`bundleId`**     | <code>string</code>              | The unique identifier of the bundle. **Attention**: The value `public` is reserved and cannot be used as a bundle identifier.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |                    | 0.1.0 |
| **`checksum`**     | <code>string</code>              | The checksum of the self-hosted bundle as a SHA-256 hash in hex format to verify the integrity of the bundle. **Attention**: Only supported for the `zip` artifact type.                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |                    | 0.1.0 |
| **`signature`**    | <code>string</code>              | The signature of the self-hosted bundle as a signed SHA-256 hash in base64 format to verify the integrity of the bundle. **Attention**: Only supported for the `zip` artifact type.                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |                    | 0.1.0 |
| **`url`**          | <code>string</code>              | The URL of the bundle to download. For the `zip` artifact type, the URL must point to a ZIP file. For the `manifest` artifact type, the URL serves as the base URL to download the individual files. For example, if the URL is `https://example.com/download`, the plugin will download the file with the href `index.html` from `https://example.com/download?href=index.html`. To **verify the integrity** of the file, the server should return a `X-Checksum` header with the SHA-256 hash in hex format. To **verify the signature** of the file, the server should return a `X-Signature` header with the signed SHA-256 hash in base64 format. |                    | 0.1.0 |


#### FetchChannelsOptions

| Prop         | Type                | Description                               | Default         | Since |
| ------------ | ------------------- | ----------------------------------------- | --------------- | ----- |
| **`limit`**  | <code>number</code> | The maximum number of channels to return. | <code>50</code> | 0.1.0 |
| **`offset`** | <code>number</code> | The number of channels to skip.           | <code>0</code>  | 0.1.0 |
| **`query`**  | <code>string</code> | The query to filter channels by name.     |                 | 0.1.0 |


#### FetchChannelsResult

| Prop           | Type            | Description           | Since |
| -------------- | --------------- | --------------------- | ----- |
| **`channels`** | <code>{}</code> | The list of channels. | 0.1.0 |


#### Channel

| Prop       | Type                | Description                           | Since |
| ---------- | ------------------- | ------------------------------------- | ----- |
| **`id`**   | <code>string</code> | The unique identifier of the channel. | 0.1.0 |
| **`name`** | <code>string</code> | The name of the channel.              | 0.1.0 |


#### FetchLatestBundleOptions

| Prop          | Type                | Description                                                      | Since |
| ------------- | ------------------- | ---------------------------------------------------------------- | ----- |
| **`channel`** | <code>string</code> | The name of the channel where the latest bundle is fetched from. | 0.1.0 |


#### FetchLatestBundleResult

| Prop                   | Type                                    | Description                                                                                                                                                                                  | Since |
| ---------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`artifactType`**     | <code>'manifest' \| 'zip'</code>        | The artifact type of the bundle.                                                                                                                                                             | 0.1.0 |
| **`bundleId`**         | <code>string \| null</code>             | The unique identifier of the latest bundle. On Capawesome Cloud, this is the ID of the app build artifact. If `null`, no bundle is available.                                                | 0.1.0 |
| **`checksum`**         | <code>string</code>                     | The checksum of the latest bundle if the bundle is self-hosted. If the bundle is hosted on Capawesome Cloud, the checksum will be returned as response header when downloading the bundle.   | 0.1.0 |
| **`customProperties`** | <code>{ [key: string]: string; }</code> | Custom properties that are associated with the latest bundle.                                                                                                                                | 0.1.0 |
| **`downloadUrl`**      | <code>string</code>                     | The URL of the latest bundle to download. Pass this URL to the `downloadBundle(...)` method to download the bundle.                                                                          | 0.1.0 |
| **`signature`**        | <code>string</code>                     | The signature of the latest bundle if the bundle is self-hosted. If the bundle is hosted on Capawesome Cloud, the signature will be returned as response header when downloading the bundle. | 0.1.0 |


#### GetBlockedBundlesResult

| Prop            | Type            | Description                                            | Since |
| --------------- | --------------- | ------------------------------------------------------ | ----- |
| **`bundleIds`** | <code>{}</code> | An array of unique identifiers of all blocked bundles. | 0.1.0 |


#### GetBundlesResult

| Prop            | Type            | Description                                              | Since |
| --------------- | --------------- | -------------------------------------------------------- | ----- |
| **`bundleIds`** | <code>{}</code> | An array of unique identifiers of all available bundles. | 0.1.0 |


#### GetChannelResult

| Prop          | Type                        | Description                                                        | Since |
| ------------- | --------------------------- | ------------------------------------------------------------------ | ----- |
| **`channel`** | <code>string \| null</code> | The channel name. If `null`, the app is using the default channel. | 0.1.0 |


#### GetConfigResult

| Prop                     | Type                                | Description                                                              | Since |
| ------------------------ | ----------------------------------- | ------------------------------------------------------------------------ | ----- |
| **`appId`**              | <code>string \| null</code>         | The app ID used to identify the app. If `null`, no app ID is configured. | 0.1.0 |
| **`autoUpdateStrategy`** | <code>'none' \| 'background'</code> | The auto-update strategy for live updates.                               | 0.1.0 |


#### GetDownloadedBundlesResult

| Prop            | Type            | Description                                               | Since |
| --------------- | --------------- | --------------------------------------------------------- | ----- |
| **`bundleIds`** | <code>{}</code> | An array of unique identifiers of all downloaded bundles. | 0.1.0 |


#### GetCurrentBundleResult

| Prop           | Type                        | Description                                                                               | Since |
| -------------- | --------------------------- | ----------------------------------------------------------------------------------------- | ----- |
| **`bundleId`** | <code>string \| null</code> | The unique identifier of the current bundle. If `null`, the default bundle is being used. | 0.1.0 |


#### GetCustomIdResult

| Prop           | Type                        | Description                                                                  | Since |
| -------------- | --------------------------- | ---------------------------------------------------------------------------- | ----- |
| **`customId`** | <code>string \| null</code> | The custom identifier of the device. If `null`, no custom identifier is set. | 0.1.0 |


#### GetDeviceIdResult

| Prop           | Type                | Description                                                                                                                                                                                                                                                                    | Since |
| -------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----- |
| **`deviceId`** | <code>string</code> | The unique identifier of the device. On iOS, [`identifierForVendor`](https://developer.apple.com/documentation/uikit/uidevice/1620059-identifierforvendor) is used. The value of this property is the same for apps that come from the same vendor running on the same device. | 0.1.0 |


#### IsSyncingResult

| Prop          | Type                 | Description                                        | Since |
| ------------- | -------------------- | -------------------------------------------------- | ----- |
| **`syncing`** | <code>boolean</code> | Whether a sync operation is currently in progress. | 0.1.0 |


#### GetNextBundleResult

| Prop           | Type                        | Description                                                                            | Since |
| -------------- | --------------------------- | -------------------------------------------------------------------------------------- | ----- |
| **`bundleId`** | <code>string \| null</code> | The unique identifier of the next bundle. If `null`, the default bundle is being used. | 0.1.0 |


#### GetVersionCodeResult

| Prop              | Type                | Description                                                                                                                                                      | Since |
| ----------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`versionCode`** | <code>string</code> | The version code of the app. On **Android**, this is the `versionCode` from `PackageInfo`. On **iOS**, this is the `CFBundleVersion` from the `Info.plist` file. | 0.1.0 |


#### GetVersionNameResult

| Prop              | Type                | Description                                                                                                                                                                 | Since |
| ----------------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`versionName`** | <code>string</code> | The version name of the app. On **Android**, this is the `versionName` from `PackageInfo`. On **iOS**, this is the `CFBundleShortVersionString` from the `Info.plist` file. | 0.1.0 |


#### ReadyResult

| Prop                   | Type                        | Description                                                                             | Since |
| ---------------------- | --------------------------- | --------------------------------------------------------------------------------------- | ----- |
| **`previousBundleId`** | <code>string \| null</code> | The identifier of the previous bundle used. If `null`, the default bundle was used.     | 0.1.0 |
| **`currentBundleId`**  | <code>string \| null</code> | The identifier of the current bundle used. If `null`, the default bundle is being used. | 0.1.0 |
| **`rollback`**         | <code>boolean</code>        | Whether or not the app was reset to the default bundle.                                 | 0.1.0 |


#### SetChannelOptions

| Prop          | Type                        | Description                                         | Since |
| ------------- | --------------------------- | --------------------------------------------------- | ----- |
| **`channel`** | <code>string \| null</code> | The channel name. Set `null` to remove the channel. | 0.1.0 |


#### SetConfigOptions

| Prop        | Type                        | Description                                                                                                         | Since |
| ----------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------- | ----- |
| **`appId`** | <code>string \| null</code> | The app ID used to identify the app. Set `null` to reset to the value from the `APP_ID` preference in `config.xml`. | 0.1.0 |


#### SetCustomIdOptions

| Prop           | Type                        | Description                                                                      | Since |
| -------------- | --------------------------- | -------------------------------------------------------------------------------- | ----- |
| **`customId`** | <code>string \| null</code> | The custom identifier of the device. Set `null` to remove the custom identifier. | 0.1.0 |


#### SetNextBundleOptions

| Prop           | Type                        | Description                                                                                                   | Since |
| -------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------- | ----- |
| **`bundleId`** | <code>string \| null</code> | The unique identifier of the bundle to use. Set `null` to use the default bundle (same as calling `reset()`). | 0.1.0 |


#### SyncOptions

| Prop          | Type                | Description                                                      | Since |
| ------------- | ------------------- | ---------------------------------------------------------------- | ----- |
| **`channel`** | <code>string</code> | The name of the channel where the latest bundle is fetched from. | 0.1.0 |


#### SyncResult

| Prop               | Type                        | Description                                                                                                | Since |
| ------------------ | --------------------------- | ---------------------------------------------------------------------------------------------------------- | ----- |
| **`nextBundleId`** | <code>string \| null</code> | The identifier of the next bundle to use. If `null`, the app is up-to-date and no new bundle is available. | 0.1.0 |


#### DownloadBundleProgressEvent

Event that is triggered when the download progress of a bundle changes.

| Prop                  | Type                | Description                                                             | Since |
| --------------------- | ------------------- | ----------------------------------------------------------------------- | ----- |
| **`bundleId`**        | <code>string</code> | The unique identifier of the bundle that is being downloaded.           | 0.1.0 |
| **`downloadedBytes`** | <code>number</code> | The number of bytes that have been downloaded.                          | 0.1.0 |
| **`progress`**        | <code>number</code> | The progress of the download in percent as a value between `0` and `1`. | 0.1.0 |
| **`totalBytes`**      | <code>number</code> | The total number of bytes to download.                                  | 0.1.0 |


#### PluginListenerHandle

Handle returned from `addListener(...)`. Call `remove()` to detach the
listener.

| Prop         | Type                      |
| ------------ | ------------------------- |
| **`remove`** | <code>() =&gt; any</code> |


#### NextBundleSetEvent

Event that is triggered when a bundle is set as the next bundle.

| Prop           | Type                        | Description                                                                                                     | Since |
| -------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------- | ----- |
| **`bundleId`** | <code>string \| null</code> | The unique identifier of the bundle that is set as the next bundle. If `null`, the default bundle will be used. | 0.1.0 |


### Type Aliases


#### DownloadBundleProgressListener

Listener for the download progress of a bundle.

<code>(event: <a href="#downloadbundleprogressevent">DownloadBundleProgressEvent</a>): void</code>


#### NextBundleSetListener

Listener for when a bundle is set as the next bundle.

<code>(event: <a href="#nextbundlesetevent">NextBundleSetEvent</a>): void</code>

</docgen-api>


## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

See [LICENSE](LICENSE).
