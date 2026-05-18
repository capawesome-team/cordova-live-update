package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.NonNull;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class FetchChannelsResult implements Result {

    @NonNull
    private final ChannelResult[] channels;

    public FetchChannelsResult(@NonNull ChannelResult[] channels) {
        this.channels = channels;
    }

    @NonNull
    @Override
    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        JSONArray channelsArray = new JSONArray();
        for (ChannelResult channel : channels) {
            channelsArray.put(channel.toJSObject());
        }
        result.put("channels", channelsArray);
        return result;
    }
}
