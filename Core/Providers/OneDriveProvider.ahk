#Requires AutoHotkey v2.0

class OneDriveProvider extends CloudSyncProvider {
    Name := "onedrive"

    Connect(config := "") {
        token := OneDriveOAuth.GetAccessToken()
        response := HttpClient.Request(
            "GET",
            "https://graph.microsoft.com/v1.0/me/drive?$select=id",
            Map(
                "Authorization", "Bearer " token,
                "Accept", "application/json"
            ),
            "",
            10000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("OneDrive authentication failed.")

        return true
    }

    ValidateConnection() {
        return this.Connect()
    }

    GetTarget() {
        return AppState.CloudSyncOneDrivePath
    }

    Download() {
        this.Connect()

        path := Trim(AppState.CloudSyncOneDrivePath, "/")
        if path == ""
            path := "CapsLock-/capslock-sync.json"

        metadataResponse := HttpClient.Request(
            "GET",
            "https://graph.microsoft.com/v1.0/me/drive/root:/"
                UriEncodePath(path)
                "?$select=id,name,eTag,lastModifiedDateTime,@microsoft.graph.downloadUrl",
            Map(
                "Authorization", "Bearer " OneDriveOAuth.GetAccessToken(),
                "Accept", "application/json"
            ),
            "",
            10000
        )

        if metadataResponse.status == 404
            return {exists: false}

        if !HttpClient.IsSuccess(metadataResponse)
            throw Error("OneDrive target lookup failed.")

        metadata := Json.Parse(metadataResponse.body)
        downloadUrl := metadata.Get("@microsoft.graph.downloadUrl", "")
        if downloadUrl == ""
            throw Error("OneDrive did not return a download URL.")

        downloadResponse := HttpClient.Request(
            "GET",
            downloadUrl,
            "",
            "",
            15000
        )

        if !HttpClient.IsSuccess(downloadResponse)
            throw Error("OneDrive download failed.")

        package := CloudSyncModel.Deserialize(downloadResponse.body)
        if !CloudSyncModel.VerifyPackage(package)
            throw Error("The OneDrive file is not a valid CapsLock sync package.")

        return {
            exists: true,
            text: downloadResponse.body,
            fingerprint: package["integrity"]["contentHash"],
            revision: package["revision"]["id"],
            providerRevision: metadata.Get("eTag", "")
        }
    }

    Upload(packageText, fingerprint := "", expectedRevision := "") {
        this.Connect()

        path := Trim(AppState.CloudSyncOneDrivePath, "/")
        if path == ""
            path := "CapsLock-/capslock-sync.json"

        url := "https://graph.microsoft.com/v1.0/me/drive/root:/"
            . UriEncodePath(path)
            . ":/content"

        headers := Map(
            "Authorization", "Bearer " OneDriveOAuth.GetAccessToken(),
            "Content-Type", "application/json"
        )

        if expectedRevision != ""
            headers["If-Match"] := expectedRevision

        response := HttpClient.Request(
            "PUT",
            url,
            headers,
            packageText,
            15000
        )

        if response.status == 412
            throw Error("The OneDrive sync file changed concurrently.")

        if !HttpClient.IsSuccess(response)
            throw Error("OneDrive upload failed. HTTP " response.status)

        package := CloudSyncModel.Deserialize(packageText)
        result := Json.Parse(response.body)

        return {
            ok: true,
            fingerprint: fingerprint != ""
                ? fingerprint
                : package["integrity"]["contentHash"],
            revision: package["revision"]["id"],
            providerRevision: result.Get("eTag", "")
        }
    }

    Disconnect() {
        return OneDriveOAuth.Disconnect()
    }
}
