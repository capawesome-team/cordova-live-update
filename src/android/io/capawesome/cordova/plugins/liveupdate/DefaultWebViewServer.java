package io.capawesome.cordova.plugins.liveupdate;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import java.io.File;

/**
 * {@link WebViewServer} for the standard Cordova WebView. Content is served through the
 * registered {@link LiveUpdatePathHandler}; switching bundles is a matter of updating the
 * active directory and reloading the WebView.
 */
public class DefaultWebViewServer implements WebViewServer {

    @NonNull
    private final LiveUpdatePlugin plugin;

    @NonNull
    private final LiveUpdatePathHandler pathHandler;

    public DefaultWebViewServer(@NonNull LiveUpdatePlugin plugin, @NonNull LiveUpdatePathHandler pathHandler) {
        this.plugin = plugin;
        this.pathHandler = pathHandler;
    }

    @Override
    public void activate(@Nullable File bundleDir) {
        pathHandler.setActiveBundleDir(bundleDir);
        plugin.reloadWebView();
    }

    @Override
    public void prime(@Nullable File bundleDir) {
        pathHandler.setActiveBundleDir(bundleDir);
    }

    @Nullable
    @Override
    public File getActiveBundleDir() {
        return pathHandler.getActiveBundleDir();
    }
}
