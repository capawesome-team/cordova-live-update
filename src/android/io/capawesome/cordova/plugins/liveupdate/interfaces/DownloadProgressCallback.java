package io.capawesome.cordova.plugins.liveupdate.interfaces;

public interface DownloadProgressCallback {
    void onProgress(long downloadedBytes, long totalBytes);
}
