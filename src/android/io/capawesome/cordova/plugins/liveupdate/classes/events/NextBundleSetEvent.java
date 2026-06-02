package io.capawesome.cordova.plugins.liveupdate.classes.events;

import androidx.annotation.Nullable;
import org.json.JSONException;
import org.json.JSONObject;

public class NextBundleSetEvent {

    @Nullable
    private final String bundleId;

    public NextBundleSetEvent(@Nullable String bundleId) {
        this.bundleId = bundleId;
    }

    @Nullable
    public String getBundleId() {
        return bundleId;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("bundleId", bundleId == null ? JSONObject.NULL : bundleId);
        return result;
    }
}
