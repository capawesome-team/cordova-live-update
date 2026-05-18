package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class GetChannelResult implements Result {

    @Nullable
    private String channel;

    public GetChannelResult(@Nullable String channel) {
        this.channel = channel;
    }

    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("channel", channel == null ? JSONObject.NULL : channel);
        return result;
    }
}
