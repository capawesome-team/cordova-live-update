package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class GetNextBundleResult implements Result {

    @Nullable
    private String bundleId;

    public GetNextBundleResult(@Nullable String bundleId) {
        this.bundleId = bundleId;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("bundleId", bundleId == null ? JSONObject.NULL : bundleId);
        return result;
    }
}
