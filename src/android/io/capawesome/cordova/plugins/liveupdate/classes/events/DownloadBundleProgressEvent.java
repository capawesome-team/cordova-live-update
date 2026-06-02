package io.capawesome.cordova.plugins.liveupdate.classes.events;

import androidx.annotation.NonNull;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class DownloadBundleProgressEvent implements Result {

    @NonNull
    private final String bundleId;

    private final long downloadedBytes;
    private final long totalBytes;
    private final double progress;

    public DownloadBundleProgressEvent(@NonNull String bundleId, long downloadedBytes, long totalBytes) {
        this.bundleId = bundleId;
        this.downloadedBytes = downloadedBytes;
        this.totalBytes = totalBytes;
        this.progress = (double) downloadedBytes / (double) totalBytes;
    }

    @NonNull
    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("bundleId", bundleId);
        result.put("downloadedBytes", downloadedBytes);
        result.put("progress", progress);
        result.put("totalBytes", totalBytes);
        return result;
    }
}
