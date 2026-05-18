package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.NonNull;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class GetBundlesResult implements Result {

    @NonNull
    private String[] bundleIds;

    public GetBundlesResult(@NonNull String[] bundleIds) {
        this.bundleIds = bundleIds;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONArray bundleIdsResult = new JSONArray();
        for (String bundleId : bundleIds) {
            bundleIdsResult.put(bundleId);
        }

        JSONObject result = new JSONObject();
        result.put("bundleIds", bundleIdsResult);
        return result;
    }
}
