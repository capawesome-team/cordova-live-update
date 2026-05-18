package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.NonNull;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class ChannelResult implements Result {

    @NonNull
    private final String id;

    @NonNull
    private final String name;

    public ChannelResult(@NonNull String id, @NonNull String name) {
        this.id = id;
        this.name = name;
    }

    @NonNull
    @Override
    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("id", id);
        result.put("name", name);
        return result;
    }
}
