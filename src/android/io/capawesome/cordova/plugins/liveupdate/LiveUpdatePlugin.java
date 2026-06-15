package io.capawesome.cordova.plugins.liveupdate;

import android.app.Activity;
import android.content.Context;
import android.content.res.Resources;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.classes.events.DownloadBundleProgressEvent;
import io.capawesome.cordova.plugins.liveupdate.classes.events.NextBundleSetEvent;
import io.capawesome.cordova.plugins.liveupdate.classes.options.DeleteBundleOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.options.DownloadBundleOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.options.FetchChannelsOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.options.FetchLatestBundleOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.options.SetChannelOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.options.SetConfigOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.options.SetCustomIdOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.options.SetNextBundleOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.options.SyncOptions;
import io.capawesome.cordova.plugins.liveupdate.classes.results.FetchChannelsResult;
import io.capawesome.cordova.plugins.liveupdate.classes.results.FetchLatestBundleResult;
import io.capawesome.cordova.plugins.liveupdate.classes.results.GetBlockedBundlesResult;
import io.capawesome.cordova.plugins.liveupdate.classes.results.GetConfigResult;
import io.capawesome.cordova.plugins.liveupdate.classes.results.GetCurrentBundleResult;
import io.capawesome.cordova.plugins.liveupdate.classes.results.GetDownloadedBundlesResult;
import io.capawesome.cordova.plugins.liveupdate.classes.results.GetNextBundleResult;
import io.capawesome.cordova.plugins.liveupdate.classes.results.IsSyncingResult;
import io.capawesome.cordova.plugins.liveupdate.interfaces.EmptyCallback;
import io.capawesome.cordova.plugins.liveupdate.interfaces.NonEmptyCallback;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaPluginPathHandler;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class LiveUpdatePlugin extends CordovaPlugin {

    public static final String TAG = "LiveUpdate";
    public static final String VERSION = "0.1.0";
    public static final String SHARED_PREFERENCES_NAME = "CapawesomeLiveUpdate"; // DO NOT CHANGE
    public static final String ERROR_APP_ID_MISSING = "appId must be configured.";
    public static final String ERROR_BUNDLE_EXISTS = "bundle already exists.";
    public static final String ERROR_BUNDLE_ID_MISSING = "bundleId must be provided.";
    public static final String ERROR_BUNDLE_INDEX_HTML_MISSING = "The bundle does not contain an index.html file.";
    public static final String ERROR_BUNDLE_NOT_FOUND = "bundle not found.";
    public static final String ERROR_CHECKSUM_CALCULATION_FAILED = "Failed to calculate checksum.";
    public static final String ERROR_CHECKSUM_MISMATCH = "Checksum mismatch.";
    public static final String ERROR_CUSTOM_ID_MISSING = "customId must be provided.";
    public static final String ERROR_DOWNLOAD_FAILED = "Bundle could not be downloaded.";
    public static final String ERROR_HTTP_TIMEOUT = "Request timed out.";
    public static final String ERROR_URL_MISSING = "url must be provided.";
    public static final String ERROR_SIGNATURE_VERIFICATION_FAILED = "Signature verification failed.";
    public static final String ERROR_PUBLIC_KEY_INVALID = "Invalid public key.";
    public static final String ERROR_SIGNATURE_MISSING = "Bundle does not contain a signature.";
    public static final String ERROR_SYNC_IN_PROGRESS = "Sync is already in progress.";
    public static final String ERROR_UNKNOWN_ERROR = "An unknown error has occurred.";
    public static final String ERROR_PLUGIN_NOT_INITIALIZED = "LiveUpdate plugin failed to initialize.";
    public static final String ERROR_LISTENER_ID_MISSING = "listenerId must be provided.";
    public static final String EVENT_DOWNLOAD_BUNDLE_PROGRESS = "downloadBundleProgress";
    public static final String EVENT_NEXT_BUNDLE_SET = "nextBundleSet";

    @Nullable
    private LiveUpdateConfig config;

    @Nullable
    private LiveUpdate implementation;

    @Nullable
    private LiveUpdatePathHandler pathHandler;

    @Nullable
    private CordovaPluginPathHandler cordovaPathHandler;

    private final Map<String, ListenerRegistration> listeners = new ConcurrentHashMap<>();

    private static final class ListenerRegistration {

        @NonNull
        final String eventName;

        @NonNull
        final CallbackContext callback;

        ListenerRegistration(@NonNull String eventName, @NonNull CallbackContext callback) {
            this.eventName = eventName;
            this.callback = callback;
        }
    }

    @Override
    protected void pluginInitialize() {
        super.pluginInitialize();
        try {
            config = loadLiveUpdateConfig();
            if (pathHandler == null) {
                pathHandler = new LiveUpdatePathHandler();
            }
            implementation = new LiveUpdate(config, this, createWebViewServer());
        } catch (Exception exception) {
            Log.e(TAG, "Failed to initialize LiveUpdate plugin: " + exception.getMessage(), exception);
        }
    }

    @NonNull
    private WebViewServer createWebViewServer() {
        Object engine = webView == null ? null : webView.getEngine();
        if (IonicWebViewServer.isSupported(engine)) {
            Log.d(TAG, "Detected Ionic WebView engine; serving bundles via the server base path.");
            return new IonicWebViewServer(this, engine);
        }
        return new DefaultWebViewServer(this, pathHandler);
    }

    @Override
    public CordovaPluginPathHandler getPathHandler() {
        if (pathHandler == null) {
            pathHandler = new LiveUpdatePathHandler();
        }
        if (cordovaPathHandler == null) {
            cordovaPathHandler = new CordovaPluginPathHandler(pathHandler);
        }
        return cordovaPathHandler;
    }

    @Override
    public void onResume(boolean multitasking) {
        super.onResume(multitasking);
        if (implementation != null) {
            implementation.handleOnResume();
        }
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        if (implementation == null || config == null) {
            callbackContext.error(ERROR_PLUGIN_NOT_INITIALIZED);
            return true;
        }
        try {
            switch (action) {
                case "clearBlockedBundles":
                    implementation.clearBlockedBundles();
                    resolve(callbackContext);
                    return true;
                case "deleteBundle":
                    executeDeleteBundle(args, callbackContext);
                    return true;
                case "downloadBundle":
                    executeDownloadBundle(args, callbackContext);
                    return true;
                case "fetchChannels":
                    executeFetchChannels(args, callbackContext);
                    return true;
                case "fetchLatestBundle":
                    executeFetchLatestBundle(args, callbackContext);
                    return true;
                case "getBlockedBundles":
                    implementation.getBlockedBundles(resultCallback(callbackContext));
                    return true;
                case "getBundles":
                    implementation.getBundles(resultCallback(callbackContext));
                    return true;
                case "getChannel":
                    implementation.getChannel(resultCallback(callbackContext));
                    return true;
                case "getConfig":
                    implementation.getConfig(resultCallback(callbackContext));
                    return true;
                case "getCurrentBundle":
                    implementation.getCurrentBundle(resultCallback(callbackContext));
                    return true;
                case "getCustomId":
                    implementation.getCustomId(resultCallback(callbackContext));
                    return true;
                case "getDeviceId":
                    implementation.getDeviceId(resultCallback(callbackContext));
                    return true;
                case "getDownloadedBundles":
                    implementation.getDownloadedBundles(resultCallback(callbackContext));
                    return true;
                case "getNextBundle":
                    implementation.getNextBundle(resultCallback(callbackContext));
                    return true;
                case "getVersionCode":
                    implementation.getVersionCode(resultCallback(callbackContext));
                    return true;
                case "getVersionName":
                    implementation.getVersionName(resultCallback(callbackContext));
                    return true;
                case "isSyncing":
                    implementation.isSyncing(resultCallback(callbackContext));
                    return true;
                case "ready":
                    implementation.ready(resultCallback(callbackContext));
                    return true;
                case "reload":
                    implementation.reload();
                    resolve(callbackContext);
                    return true;
                case "reset":
                    implementation.reset();
                    resolve(callbackContext);
                    return true;
                case "resetConfig":
                    implementation.resetConfig();
                    resolve(callbackContext);
                    return true;
                case "setChannel":
                    executeSetChannel(args, callbackContext);
                    return true;
                case "setConfig":
                    executeSetConfig(args, callbackContext);
                    return true;
                case "setCustomId":
                    executeSetCustomId(args, callbackContext);
                    return true;
                case "setNextBundle":
                    executeSetNextBundle(args, callbackContext);
                    return true;
                case "sync":
                    executeSync(args, callbackContext);
                    return true;
                case "addListener":
                    executeAddListener(args, callbackContext);
                    return true;
                case "removeListener":
                    executeRemoveListener(args, callbackContext);
                    return true;
                case "removeAllListeners":
                    executeRemoveAllListeners(callbackContext);
                    return true;
                default:
                    return false;
            }
        } catch (Exception exception) {
            reject(callbackContext, exception);
            return true;
        }
    }

    private void executeDeleteBundle(JSONArray args, CallbackContext callbackContext) throws JSONException {
        JSONObject options = args.optJSONObject(0);
        String bundleId = options == null ? null : (options.isNull("bundleId") ? null : options.optString("bundleId", null));
        if (bundleId == null) {
            callbackContext.error(ERROR_BUNDLE_ID_MISSING);
            return;
        }
        implementation.deleteBundle(new DeleteBundleOptions(bundleId), emptyCallback(callbackContext));
    }

    private void executeDownloadBundle(JSONArray args, CallbackContext callbackContext) throws JSONException {
        JSONObject options = args.optJSONObject(0);
        if (options == null) {
            callbackContext.error(ERROR_BUNDLE_ID_MISSING);
            return;
        }
        String artifactType = options.optString("artifactType", "zip");
        String bundleId = options.isNull("bundleId") ? null : options.optString("bundleId", null);
        if (bundleId == null) {
            callbackContext.error(ERROR_BUNDLE_ID_MISSING);
            return;
        }
        String checksum = options.isNull("checksum") ? null : options.optString("checksum", null);
        String signature = options.isNull("signature") ? null : options.optString("signature", null);
        String url = options.isNull("url") ? null : options.optString("url", null);
        if (url == null) {
            callbackContext.error(ERROR_URL_MISSING);
            return;
        }
        implementation.downloadBundle(
            new DownloadBundleOptions(artifactType, bundleId, checksum, signature, url),
            emptyCallback(callbackContext)
        );
    }

    private void executeFetchChannels(JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (config.getAppId() == null || config.getAppId().isEmpty()) {
            callbackContext.error(ERROR_APP_ID_MISSING);
            return;
        }
        JSONObject options = args.optJSONObject(0);
        if (options == null) {
            options = new JSONObject();
        }
        implementation.fetchChannels(new FetchChannelsOptions(options), nonEmptyCallback(callbackContext));
    }

    private void executeFetchLatestBundle(JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (config.getAppId() == null || config.getAppId().isEmpty()) {
            callbackContext.error(ERROR_APP_ID_MISSING);
            return;
        }
        JSONObject options = args.optJSONObject(0);
        if (options == null) {
            options = new JSONObject();
        }
        implementation.fetchLatestBundle(new FetchLatestBundleOptions(options), nonEmptyCallback(callbackContext));
    }

    private void executeSetChannel(JSONArray args, CallbackContext callbackContext) {
        JSONObject options = args.optJSONObject(0);
        String channel = options == null || options.isNull("channel") ? null : options.optString("channel", null);
        implementation.setChannel(new SetChannelOptions(channel), emptyCallback(callbackContext));
    }

    private void executeSetConfig(JSONArray args, CallbackContext callbackContext) throws JSONException {
        JSONObject options = args.optJSONObject(0);
        if (options == null) {
            options = new JSONObject();
        }
        implementation.setConfig(new SetConfigOptions(options));
        resolve(callbackContext);
    }

    private void executeSetCustomId(JSONArray args, CallbackContext callbackContext) {
        JSONObject options = args.optJSONObject(0);
        String customId = options == null || options.isNull("customId") ? null : options.optString("customId", null);
        if (customId == null) {
            callbackContext.error(ERROR_CUSTOM_ID_MISSING);
            return;
        }
        implementation.setCustomId(new SetCustomIdOptions(customId), emptyCallback(callbackContext));
    }

    private void executeSetNextBundle(JSONArray args, CallbackContext callbackContext) throws JSONException {
        JSONObject options = args.optJSONObject(0);
        if (options == null) {
            options = new JSONObject();
        }
        implementation.setNextBundle(new SetNextBundleOptions(options), emptyCallback(callbackContext));
    }

    private void executeSync(JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (config.getAppId() == null || config.getAppId().isEmpty()) {
            callbackContext.error(ERROR_APP_ID_MISSING);
            return;
        }
        JSONObject options = args.optJSONObject(0);
        if (options == null) {
            options = new JSONObject();
        }
        implementation.sync(new SyncOptions(options), nonEmptyCallback(callbackContext));
    }

    private void executeAddListener(JSONArray args, CallbackContext callbackContext) throws JSONException {
        String eventName = args.optString(0, null);
        String listenerId = args.optString(1, null);
        if (eventName == null || listenerId == null) {
            callbackContext.error(ERROR_LISTENER_ID_MISSING);
            return;
        }
        listeners.put(listenerId, new ListenerRegistration(eventName, callbackContext));
        // Keep the callback alive so we can deliver events to it later.
        PluginResult ack = new PluginResult(PluginResult.Status.NO_RESULT);
        ack.setKeepCallback(true);
        callbackContext.sendPluginResult(ack);
    }

    private void executeRemoveListener(JSONArray args, CallbackContext callbackContext) throws JSONException {
        JSONObject options = args.optJSONObject(0);
        String listenerId = options == null || options.isNull("listenerId") ? null : options.optString("listenerId", null);
        if (listenerId == null) {
            callbackContext.error(ERROR_LISTENER_ID_MISSING);
            return;
        }
        ListenerRegistration entry = listeners.remove(listenerId);
        if (entry != null) {
            releaseCallback(entry.callback);
        }
        resolve(callbackContext);
    }

    private void executeRemoveAllListeners(CallbackContext callbackContext) {
        Iterator<Map.Entry<String, ListenerRegistration>> it = listeners.entrySet().iterator();
        while (it.hasNext()) {
            ListenerRegistration entry = it.next().getValue();
            releaseCallback(entry.callback);
            it.remove();
        }
        resolve(callbackContext);
    }

    public void notifyDownloadBundleProgressListeners(@NonNull DownloadBundleProgressEvent event) {
        try {
            notifyListeners(EVENT_DOWNLOAD_BUNDLE_PROGRESS, event.toJSObject());
        } catch (JSONException e) {
            Log.e(TAG, "Failed to serialize downloadBundleProgress event: " + e.getMessage(), e);
        }
    }

    public void notifyNextBundleSetListeners(@NonNull NextBundleSetEvent event) {
        try {
            notifyListeners(EVENT_NEXT_BUNDLE_SET, event.toJSObject());
        } catch (JSONException e) {
            Log.e(TAG, "Failed to serialize nextBundleSet event: " + e.getMessage(), e);
        }
    }

    private void notifyListeners(@NonNull String eventName, @NonNull JSONObject data) {
        for (ListenerRegistration entry : listeners.values()) {
            if (!entry.eventName.equals(eventName)) {
                continue;
            }
            PluginResult result = new PluginResult(PluginResult.Status.OK, data);
            result.setKeepCallback(true);
            entry.callback.sendPluginResult(result);
        }
    }

    public Context getContext() {
        return cordova.getActivity().getApplicationContext();
    }

    public Activity getActivity() {
        return cordova.getActivity();
    }

    public ExecutorService getThreadPool() {
        return cordova.getThreadPool();
    }

    public void reloadWebView() {
        cordova
            .getActivity()
            .runOnUiThread(() -> {
                if (webView != null && webView.getView() instanceof android.webkit.WebView) {
                    ((android.webkit.WebView) webView.getView()).reload();
                }
            });
    }

    private void releaseCallback(@NonNull CallbackContext callback) {
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(false);
        callback.sendPluginResult(result);
    }

    private void resolve(@NonNull CallbackContext callbackContext) {
        callbackContext.success();
    }

    private void resolve(@NonNull CallbackContext callbackContext, @NonNull JSONObject result) {
        callbackContext.success(result);
    }

    private void reject(@NonNull CallbackContext callbackContext, @NonNull Exception exception) {
        String message = exception.getMessage();
        if (exception instanceof java.net.SocketTimeoutException) {
            message = ERROR_HTTP_TIMEOUT;
        } else if (message == null) {
            message = ERROR_UNKNOWN_ERROR;
        }
        Log.e(TAG, message, exception);
        callbackContext.error(message);
    }

    private EmptyCallback emptyCallback(@NonNull CallbackContext callbackContext) {
        return new EmptyCallback() {
            @Override
            public void success() {
                resolve(callbackContext);
            }

            @Override
            public void error(@NonNull Exception exception) {
                reject(callbackContext, exception);
            }
        };
    }

    private <T extends Result> NonEmptyCallback<T> nonEmptyCallback(@NonNull CallbackContext callbackContext) {
        return new NonEmptyCallback<T>() {
            @Override
            public void success(@NonNull T result) {
                try {
                    resolve(callbackContext, result.toJSObject());
                } catch (JSONException e) {
                    reject(callbackContext, e);
                }
            }

            @Override
            public void error(@NonNull Exception exception) {
                reject(callbackContext, exception);
            }
        };
    }

    private <T extends Result> NonEmptyCallback<T> resultCallback(@NonNull CallbackContext callbackContext) {
        return nonEmptyCallback(callbackContext);
    }

    @NonNull
    private LiveUpdateConfig loadLiveUpdateConfig() {
        LiveUpdateConfig cfg = new LiveUpdateConfig();
        Context ctx = getContext();
        Resources res = ctx.getResources();
        String pkg = ctx.getPackageName();

        String appId = readStringRes(res, pkg, "capawesome_live_update_app_id");
        if (appId != null) {
            cfg.setAppId(appId);
        }
        String defaultChannel = readStringRes(res, pkg, "capawesome_live_update_default_channel");
        if (defaultChannel != null) {
            cfg.setDefaultChannel(defaultChannel);
        }
        String autoUpdateStrategy = readStringRes(res, pkg, "capawesome_live_update_auto_update_strategy");
        if (autoUpdateStrategy != null) {
            cfg.setAutoUpdateStrategy(autoUpdateStrategy);
        }
        String publicKey = readStringRes(res, pkg, "capawesome_live_update_public_key");
        if (publicKey != null) {
            cfg.setPublicKey(publicKey);
        }
        String serverDomain = readStringRes(res, pkg, "capawesome_live_update_server_domain");
        if (serverDomain != null) {
            cfg.setServerDomain(serverDomain);
        }
        cfg.setHttpTimeout(parseIntSafe(readStringRes(res, pkg, "capawesome_live_update_http_timeout"), cfg.getHttpTimeout()));
        cfg.setReadyTimeout(parseIntSafe(readStringRes(res, pkg, "capawesome_live_update_ready_timeout"), cfg.getReadyTimeout()));
        cfg.setAutoDeleteBundles(
            parseBoolSafe(readStringRes(res, pkg, "capawesome_live_update_auto_delete_bundles"), cfg.getAutoDeleteBundles())
        );
        cfg.setAutoBlockRolledBackBundles(
            parseBoolSafe(
                readStringRes(res, pkg, "capawesome_live_update_auto_block_rolled_back_bundles"),
                cfg.getAutoBlockRolledBackBundles()
            )
        );
        return cfg;
    }

    @Nullable
    static String readStringRes(@NonNull Resources res, @NonNull String pkg, @NonNull String key) {
        int resId = res.getIdentifier(key, "string", pkg);
        if (resId == 0) {
            return null;
        }
        // Cordova injects a single-space sentinel for "unset" preferences (see
        // plugin.xml). Treat whitespace-only values as null.
        String value = res.getString(resId).trim();
        return value.isEmpty() ? null : value;
    }

    private static int parseIntSafe(@Nullable String value, int fallback) {
        if (value == null || value.isEmpty()) {
            return fallback;
        }
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    private static boolean parseBoolSafe(@Nullable String value, boolean fallback) {
        if (value == null || value.isEmpty()) {
            return fallback;
        }
        return Boolean.parseBoolean(value);
    }
}
