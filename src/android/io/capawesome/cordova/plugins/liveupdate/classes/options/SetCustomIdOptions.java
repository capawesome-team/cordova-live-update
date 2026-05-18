package io.capawesome.cordova.plugins.liveupdate.classes.options;

import androidx.annotation.NonNull;

public class SetCustomIdOptions {

    @NonNull
    private String customId;

    public SetCustomIdOptions(@NonNull String customId) {
        this.customId = customId;
    }

    @NonNull
    public String getCustomId() {
        return customId;
    }
}
