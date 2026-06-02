package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class SyncResult implements Result {

    @Nullable
    private final String nextBundleId;

    public SyncResult(@Nullable String nextBundleId) {
        this.nextBundleId = nextBundleId;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("nextBundleId", nextBundleId == null ? JSONObject.NULL : nextBundleId);
        return result;
    }
}
