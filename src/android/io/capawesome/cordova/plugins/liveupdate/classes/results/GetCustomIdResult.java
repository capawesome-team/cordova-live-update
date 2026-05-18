package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class GetCustomIdResult implements Result {

    @Nullable
    private String customId;

    public GetCustomIdResult(@Nullable String customId) {
        this.customId = customId;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("customId", customId == null ? JSONObject.NULL : customId);
        return result;
    }
}
