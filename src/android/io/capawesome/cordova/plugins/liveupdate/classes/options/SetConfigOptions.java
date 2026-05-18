package io.capawesome.cordova.plugins.liveupdate.classes.options;

import androidx.annotation.Nullable;
import org.json.JSONException;
import org.json.JSONObject;

public class SetConfigOptions {

    @Nullable
    private final String appId;

    public SetConfigOptions(JSONObject options) throws JSONException {
        this.appId = options.isNull("appId") ? null : options.optString("appId", null);
    }

    @Nullable
    public String getAppId() {
        return appId;
    }
}
