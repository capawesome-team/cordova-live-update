package io.capawesome.cordova.plugins.liveupdate.classes.options;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import org.json.JSONException;
import org.json.JSONObject;

public class FetchChannelsOptions {

    @Nullable
    private final Integer limit;

    @Nullable
    private final Integer offset;

    @Nullable
    private final String query;

    public FetchChannelsOptions(@NonNull JSONObject options) throws JSONException {
        this.limit = options.has("limit") && !options.isNull("limit") ? options.getInt("limit") : null;
        this.offset = options.has("offset") && !options.isNull("offset") ? options.getInt("offset") : null;
        this.query = options.isNull("query") ? null : options.optString("query", null);
    }

    @Nullable
    public Integer getLimit() {
        return limit;
    }

    @Nullable
    public Integer getOffset() {
        return offset;
    }

    @Nullable
    public String getQuery() {
        return query;
    }
}
