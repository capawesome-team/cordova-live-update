package io.capawesome.cordova.plugins.liveupdate.classes.results;

import androidx.annotation.NonNull;
import io.capawesome.cordova.plugins.liveupdate.interfaces.Result;
import org.json.JSONException;
import org.json.JSONObject;

public class IsSyncingResult implements Result {

    private final boolean syncing;

    public IsSyncingResult(boolean syncing) {
        this.syncing = syncing;
    }

    public boolean getSyncing() {
        return syncing;
    }

    @Override
    @NonNull
    public JSONObject toJSObject() throws JSONException {
        JSONObject result = new JSONObject();
        result.put("syncing", syncing);
        return result;
    }
}
