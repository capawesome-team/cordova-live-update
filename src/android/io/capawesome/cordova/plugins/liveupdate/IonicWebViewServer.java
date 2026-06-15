package io.capawesome.cordova.plugins.liveupdate;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.res.AssetManager;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;

/**
 * {@link WebViewServer} for the Ionic WebView ({@code IonicWebViewEngine}).
 *
 * <p>The Ionic WebView serves content through its own local server and never consults Cordova's
 * plugin path handlers, so {@link LiveUpdatePathHandler} has no effect. Instead the engine exposes
 * {@code setServerBasePath(String)} which we invoke via reflection (no build dependency on
 * {@code cordova-plugin-ionic-webview} is required, and not every app ships it).
 *
 * <p>{@code setServerBasePath()} can only host a filesystem path, so reverting to the built-in app
 * (e.g. on rollback) is done by copying the APK's {@code www/} assets to disk once and pointing the
 * base path at that copy. This keeps every runtime transition a {@code hostFiles → hostFiles} switch,
 * the same one the engine is exercised with in production.
 *
 * <p>Cold start is handled by the engine itself: it loads the persisted base path from its own
 * {@code WebViewSettings} preferences before the page renders. We keep that preference in sync with
 * the plugin's source of truth so the correct bundle is served on the next launch without a flash.
 */
public class IonicWebViewServer implements WebViewServer {

    // Mirrors com.ionicframework.cordova.webview.IonicWebView (cordova-plugin-ionic-webview).
    private static final String IONIC_PREFS_NAME = "WebViewSettings";
    private static final String IONIC_SERVER_PATH_KEY = "serverBasePath";
    private static final String SET_SERVER_BASE_PATH_METHOD = "setServerBasePath";

    // Directory holding the APK's www/ assets copied to disk, so the Ionic local server (which can
    // only host file paths) can be pointed back at the built-in app. Kept outside the bundles
    // directory so it is never listed as a downloaded bundle or touched by bundle cleanup.
    private static final String BUILTIN_DIRECTORY = "capawesome_live_update_builtin"; // DO NOT CHANGE!
    private static final String BUILTIN_VERSION_FILE = "capawesome_live_update_builtin.version"; // DO NOT CHANGE!
    private static final String ASSETS_WWW_DIRECTORY = "www";

    @NonNull
    private final LiveUpdatePlugin plugin;

    @NonNull
    private final Object engine;

    private final AtomicReference<File> activeBundleDir = new AtomicReference<>(null);

    public IonicWebViewServer(@NonNull LiveUpdatePlugin plugin, @NonNull Object engine) {
        this.plugin = plugin;
        this.engine = engine;
    }

    /**
     * @return {@code true} if {@code engine} is an Ionic WebView engine, i.e. it exposes
     *     {@code setServerBasePath(String)}.
     */
    public static boolean isSupported(@Nullable Object engine) {
        return engine != null && findSetServerBasePathMethod(engine) != null;
    }

    @Override
    public void activate(@Nullable File bundleDir) {
        if (bundleDir == null) {
            revertToBuiltIn();
        } else {
            setServerBasePath(bundleDir.getAbsolutePath());
            persistForColdStart(bundleDir.getAbsolutePath());
        }
        activeBundleDir.set(bundleDir);
    }

    @Override
    public void prime(@Nullable File bundleDir) {
        // The engine already applied the persisted base path during its own init, so we must not
        // reload here. We only sync our in-memory state and keep the persisted path aligned with
        // the plugin's source of truth for the next cold start.
        persistForColdStart(bundleDir == null ? null : bundleDir.getAbsolutePath());
        activeBundleDir.set(bundleDir);
    }

    @Nullable
    @Override
    public File getActiveBundleDir() {
        return activeBundleDir.get();
    }

    private void revertToBuiltIn() {
        // Extraction does file I/O and may be triggered from the main thread (the rollback timer),
        // so run it off the main thread and apply the base path once it is ready.
        plugin
            .getThreadPool()
            .execute(() -> {
                File builtInDir = ensureBuiltInExtracted();
                if (builtInDir == null) {
                    Log.e(LiveUpdatePlugin.TAG, "Failed to revert the Ionic WebView to the built-in app.");
                    return;
                }
                setServerBasePath(builtInDir.getAbsolutePath());
                // Clear the persisted path so the next cold start serves the native assets directly;
                // the extracted copy is only needed to revert within the running session.
                persistForColdStart(null);
            });
    }

    private void setServerBasePath(@NonNull String path) {
        plugin
            .getActivity()
            .runOnUiThread(() -> {
                Method method = findSetServerBasePathMethod(engine);
                if (method == null) {
                    Log.e(LiveUpdatePlugin.TAG, "IonicWebViewEngine.setServerBasePath(String) not found.");
                    return;
                }
                try {
                    method.invoke(engine, path);
                } catch (Exception exception) {
                    Log.e(LiveUpdatePlugin.TAG, "Failed to set the Ionic server base path: " + exception.getMessage(), exception);
                }
            });
    }

    private void persistForColdStart(@Nullable String path) {
        SharedPreferences prefs = plugin.getContext().getSharedPreferences(IONIC_PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putString(IONIC_SERVER_PATH_KEY, path == null ? "" : path).apply();
    }

    /**
     * Lazily copies the APK's {@code www/} assets to a filesystem directory, re-extracting when the
     * native binary changes (the bundled assets change with it).
     *
     * @return The built-in directory, or {@code null} if extraction failed.
     */
    @Nullable
    private File ensureBuiltInExtracted() {
        File directory = new File(plugin.getContext().getFilesDir(), BUILTIN_DIRECTORY);
        String currentVersion = getBinaryVersionTag();
        if (new File(directory, "index.html").isFile() && currentVersion.equals(readVersionMarker())) {
            return directory;
        }
        deleteRecursively(directory);
        try {
            copyAssetDirectory(ASSETS_WWW_DIRECTORY, directory);
            writeVersionMarker(currentVersion);
            return directory;
        } catch (IOException exception) {
            Log.e(LiveUpdatePlugin.TAG, "Failed to extract the built-in app assets: " + exception.getMessage(), exception);
            deleteRecursively(directory);
            return null;
        }
    }

    private void copyAssetDirectory(@NonNull String assetPath, @NonNull File targetDir) throws IOException {
        AssetManager assetManager = plugin.getContext().getAssets();
        String[] entries = assetManager.list(assetPath);
        if (entries == null || entries.length == 0) {
            // An empty list means a file (or an empty directory, which we can safely skip).
            copyAssetFile(assetPath, targetDir);
            return;
        }
        if (!targetDir.exists() && !targetDir.mkdirs()) {
            throw new IOException("Could not create directory: " + targetDir.getAbsolutePath());
        }
        for (String entry : entries) {
            copyAssetDirectory(assetPath + "/" + entry, new File(targetDir, entry));
        }
    }

    private void copyAssetFile(@NonNull String assetPath, @NonNull File targetFile) throws IOException {
        File parent = targetFile.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IOException("Could not create directory: " + parent.getAbsolutePath());
        }
        AssetManager assetManager = plugin.getContext().getAssets();
        try (InputStream in = assetManager.open(assetPath); OutputStream out = new FileOutputStream(targetFile)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
        }
    }

    @NonNull
    private String getBinaryVersionTag() {
        try {
            Context context = plugin.getContext();
            PackageInfo info = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            return info.versionCode + ":" + info.versionName;
        } catch (Exception exception) {
            return "unknown";
        }
    }

    @Nullable
    private String readVersionMarker() {
        File marker = new File(plugin.getContext().getFilesDir(), BUILTIN_VERSION_FILE);
        if (!marker.isFile()) {
            return null;
        }
        try (InputStream in = new FileInputStream(marker)) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buffer = new byte[256];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            return out.toString(StandardCharsets.UTF_8.name());
        } catch (IOException exception) {
            return null;
        }
    }

    private void writeVersionMarker(@NonNull String version) throws IOException {
        File marker = new File(plugin.getContext().getFilesDir(), BUILTIN_VERSION_FILE);
        try (OutputStream out = new FileOutputStream(marker)) {
            out.write(version.getBytes(StandardCharsets.UTF_8));
        }
    }

    private void deleteRecursively(@Nullable File file) {
        if (file == null || !file.exists()) {
            return;
        }
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) {
                deleteRecursively(child);
            }
        }
        file.delete();
    }

    @Nullable
    private static Method findSetServerBasePathMethod(@NonNull Object engine) {
        try {
            return engine.getClass().getMethod(SET_SERVER_BASE_PATH_METHOD, String.class);
        } catch (NoSuchMethodException exception) {
            return null;
        }
    }
}
