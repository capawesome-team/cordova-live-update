package io.capawesome.cordova.plugins.liveupdate.classes.options;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.capawesome.cordova.plugins.liveupdate.classes.UrlTemplate;
import io.capawesome.cordova.plugins.liveupdate.classes.api.CreateCheckResponseBundle;
import io.capawesome.cordova.plugins.liveupdate.enums.ArtifactType;

public class DownloadBundleOptions {

    @NonNull
    private ArtifactType artifactType;

    @NonNull
    private String bundleId;

    @Nullable
    private String checksum;

    @Nullable
    private String signature;

    @NonNull
    private String url;

    @Nullable
    private final UrlTemplate urlTemplate;

    public DownloadBundleOptions(
        @NonNull String artifactType,
        @NonNull String bundleId,
        @Nullable String checksum,
        @Nullable String signature,
        @NonNull String url
    ) {
        if (artifactType.equals("manifest")) {
            this.artifactType = ArtifactType.MANIFEST;
        } else {
            this.artifactType = ArtifactType.ZIP;
        }
        this.bundleId = bundleId;
        this.checksum = checksum;
        this.signature = signature;
        this.url = url;
        this.urlTemplate = null;
    }

    public DownloadBundleOptions(@NonNull CreateCheckResponseBundle bundle) {
        this.artifactType = bundle.getArtifactType();
        this.bundleId = bundle.getId();
        this.checksum = bundle.getChecksum();
        this.signature = bundle.getSignature();
        this.url = bundle.getUrl();
        this.urlTemplate = bundle.getUrlTemplate();
    }

    @NonNull
    public ArtifactType getArtifactType() {
        return artifactType;
    }

    @NonNull
    public String getBundleId() {
        return bundleId;
    }

    @Nullable
    public String getChecksum() {
        return checksum;
    }

    @Nullable
    public String getSignature() {
        return signature;
    }

    @NonNull
    public String getUrl() {
        return url;
    }

    /**
     * @return The template for the files of the bundle, never set for a download from JavaScript.
     */
    @Nullable
    public UrlTemplate getUrlTemplate() {
        return urlTemplate;
    }
}
