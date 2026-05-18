package io.capawesome.cordova.plugins.liveupdate;

import android.util.Log;
import android.webkit.MimeTypeMap;
import android.webkit.WebResourceResponse;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.webkit.WebViewAssetLoader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicReference;

/**
 * {@link WebViewAssetLoader.PathHandler} that serves files from the active live-update
 * bundle directory when one is set. Returns {@code null} otherwise so that Cordova's
 * default {@code www/} asset handler can serve the original APK assets.
 */
public class LiveUpdatePathHandler implements WebViewAssetLoader.PathHandler {

    private final AtomicReference<File> activeBundleDir = new AtomicReference<>(null);

    public void setActiveBundleDir(@Nullable File dir) {
        activeBundleDir.set(dir);
    }

    @Nullable
    public File getActiveBundleDir() {
        return activeBundleDir.get();
    }

    @Override
    @Nullable
    public WebResourceResponse handle(@NonNull String path) {
        File baseDir = activeBundleDir.get();
        if (baseDir == null) {
            // No live bundle active — fall through to Cordova's default www/ handler.
            return null;
        }

        String resolvedPath = path;
        if (resolvedPath.isEmpty() || resolvedPath.endsWith("/")) {
            resolvedPath = resolvedPath + "index.html";
        }

        File file = new File(baseDir, resolvedPath);

        // Defense-in-depth against path traversal: ensure the resolved file is inside baseDir.
        try {
            String canonicalBase = baseDir.getCanonicalPath();
            String canonicalFile = file.getCanonicalPath();
            if (!canonicalFile.equals(canonicalBase) && !canonicalFile.startsWith(canonicalBase + File.separator)) {
                return null;
            }
        } catch (IOException e) {
            return null;
        }

        if (!file.isFile()) {
            // Not in active bundle — let the default handler try.
            return null;
        }

        try {
            InputStream stream = new FileInputStream(file);
            String mimeType = guessMimeType(resolvedPath);
            return new WebResourceResponse(mimeType, null, stream);
        } catch (IOException e) {
            Log.e(LiveUpdatePlugin.TAG, "Failed to open bundle file: " + file.getAbsolutePath(), e);
            return null;
        }
    }

    private String guessMimeType(@NonNull String path) {
        // Mirror Cordova's SystemWebViewClient logic so behavior is consistent
        // whether we serve from the bundle or fall through to the default handler.
        if (path.endsWith(".js") || path.endsWith(".mjs")) {
            return "application/javascript";
        }
        if (path.endsWith(".wasm")) {
            return "application/wasm";
        }
        String extension = MimeTypeMap.getFileExtensionFromUrl(path);
        if (extension != null) {
            String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
            if (mime != null) {
                return mime;
            }
        }
        if (path.endsWith(".html") || path.endsWith(".htm")) {
            return "text/html";
        }
        return "application/octet-stream";
    }
}
