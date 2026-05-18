package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class GetVersionCodeResult implements Result {

    private String versionCode;

    public GetVersionCodeResult(String versionCode) {
        this.versionCode = versionCode;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("versionCode", versionCode);
        return result;
    }
}
