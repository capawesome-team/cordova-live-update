package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.NonNull;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class GetVersionNameResult implements Result {

    @NonNull
    private String versionName;

    public GetVersionNameResult(@NonNull String versionName) {
        this.versionName = versionName;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("versionName", versionName);
        return result;
    }
}
