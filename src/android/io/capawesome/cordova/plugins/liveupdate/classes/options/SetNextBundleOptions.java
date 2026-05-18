package io.capawesome.cordova.plugins.liveupdate.classes.options;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import org.json.JSONException;
import org.json.JSONObject;

public class SetNextBundleOptions {

    @Nullable
    private final String bundleId;

    public SetNextBundleOptions(@NonNull JSONObject options) throws JSONException {
        this.bundleId = options.isNull("bundleId") ? null : options.optString("bundleId", null);
    }

    @Nullable
    public String getBundleId() {
        return bundleId;
    }
}
