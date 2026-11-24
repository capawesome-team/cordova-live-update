package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.classes.api.CreateCheckResponse;
import io.capawesome.cordova.plugins.liveupdate.classes.api.CreateCheckResponseBundle;
import io.capawesome.cordova.plugins.liveupdate.enums.ArtifactType;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class FetchLatestBundleResult implements Result {

    @Nullable
    private final ArtifactType artifactType;

    @Nullable
    private final String bundleId;

    @Nullable
    private final String checksum;

    @Nullable
    private final JSONObject customProperties;

    @Nullable
    private final String downloadUrl;

    @Nullable
    private final String signature;

    public FetchLatestBundleResult(@NonNull CreateCheckResponse response) {
        CreateCheckResponseBundle bundle = response.getBundle();
        this.artifactType = bundle == null ? null : bundle.getArtifactType();
        this.bundleId = bundle == null ? null : bundle.getId();
        this.checksum = bundle == null ? null : bundle.getChecksum();
        this.customProperties = bundle == null ? null : bundle.getCustomProperties();
        this.downloadUrl = bundle == null ? null : bundle.getUrl();
        this.signature = bundle == null ? null : bundle.getSignature();
    }

    @NonNull
    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        if (artifactType != null) {
            result.put("artifactType", artifactType.getValue());
        }
        result.put("bundleId", bundleId == null ? JSONObject.NULL : bundleId);
        if (checksum != null) {
            result.put("checksum", checksum);
        }
        if (customProperties != null) {
            result.put("customProperties", customProperties);
        }
        if (downloadUrl != null) {
            result.put("downloadUrl", downloadUrl);
        }
        if (signature != null) {
            result.put("signature", signature);
        }
        return result;
    }
}
