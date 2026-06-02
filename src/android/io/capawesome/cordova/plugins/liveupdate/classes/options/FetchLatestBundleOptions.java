package io.capawesome.cordova.plugins.liveupdate.classes.options;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import org.json.JSONException;
import org.json.JSONObject;

public class FetchLatestBundleOptions {

    @Nullable
    private final String channel;

    public FetchLatestBundleOptions(@NonNull JSONObject options) throws JSONException {
        this.channel = options.optString("channel", null);
    }

    public FetchLatestBundleOptions(@Nullable String channel) {
        this.channel = channel;
    }

    @Nullable
    public String getChannel() {
        return channel;
    }
}
