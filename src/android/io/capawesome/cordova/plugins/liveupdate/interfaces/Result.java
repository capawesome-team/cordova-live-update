package io.capawesome.cordova.plugins.liveupdate.interfaces;

import org.json.JSONException;
import org.json.JSONObject;

public interface Result {
    JSONObject toJSObject() throws JSONException;
}
