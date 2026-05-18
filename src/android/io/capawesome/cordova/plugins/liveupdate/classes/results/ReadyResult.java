package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.LiveUpdate;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class ReadyResult implements Result {

    @Nullable
    private String currentBundleId;

    @Nullable
    private String previousBundleId;

    private boolean rollback;

    public ReadyResult(@Nullable String currentBundleId, @Nullable String previousBundleId, boolean rollback) {
        this.currentBundleId = currentBundleId;
        this.previousBundleId = previousBundleId;
        this.rollback = rollback;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("currentBundleId", currentBundleId == null ? JSONObject.NULL : currentBundleId);
        result.put("previousBundleId", previousBundleId == null ? JSONObject.NULL : previousBundleId);
        result.put("rollback", rollback);
        return result;
    }
}
