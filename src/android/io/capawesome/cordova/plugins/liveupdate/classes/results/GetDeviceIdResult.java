package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.NonNull;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class GetDeviceIdResult implements Result {

    @NonNull
    private String deviceId;

    public GetDeviceIdResult(@NonNull String deviceId) {
        this.deviceId = deviceId;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("deviceId", deviceId == null ? JSONObject.NULL : deviceId);
        return result;
    }
}
