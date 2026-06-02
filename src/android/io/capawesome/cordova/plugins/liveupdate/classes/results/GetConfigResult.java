package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class GetConfigResult implements Result {

    @Nullable
    private final String appId;

    @NonNull
    private final String autoUpdateStrategy;

    public GetConfigResult(@Nullable String appId, @NonNull String autoUpdateStrategy) {
        this.appId = appId;
        this.autoUpdateStrategy = autoUpdateStrategy;
    }

    @Nullable
    public String getAppId() {
        return appId;
    }

    @NonNull
    public String getAutoUpdateStrategy() {
        return autoUpdateStrategy;
    }

    @Override
    @NonNull
    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("appId", appId == null ? JSONObject.NULL : appId);
        result.put("autoUpdateStrategy", autoUpdateStrategy);
        return result;
    }
}
