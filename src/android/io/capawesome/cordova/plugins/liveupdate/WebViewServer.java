package io.capawesome.cordova.plugins.liveupdate;

import androidx.annotation.Nullable;
import java.io.File;

/**
 * Abstraction over the mechanism used to serve a live-update bundle to the WebView.
 *
 * <p>The standard Cordova WebView routes asset requests through registered plugin path
 * handlers ({@link LiveUpdatePathHandler}), whereas the Ionic WebView serves content from
 * its own local server and must be switched via {@code setServerBasePath()}. Each engine
 * gets its own implementation so the rest of the plugin stays engine-agnostic.
 */
public interface WebViewServer {
    /**
     * Switch the served content to {@code bundleDir} and reload the WebView.
     *
     * @param bundleDir The bundle directory to serve, or {@code null} to serve the built-in app.
     */
    void activate(@Nullable File bundleDir);

    /**
     * Synchronize the active bundle at cold start <strong>without</strong> reloading the WebView.
     * The content is loaded for the first time right after, so a reload would be wasteful (and,
     * for the Ionic engine, the persisted base path is already applied during its own init).
     *
     * @param bundleDir The bundle directory to serve, or {@code null} to serve the built-in app.
     */
    void prime(@Nullable File bundleDir);

    /**
     * @return The active bundle directory, or {@code null} if the built-in app is in use.
     */
    @Nullable
    File getActiveBundleDir();
}
