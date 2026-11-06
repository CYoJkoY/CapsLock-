#Requires AutoHotkey v2.0

class GoogleDriveProvider extends CloudSyncProvider {
    Name := "google-drive"
    FileName := "capslock-sync.json"

    Connect(config := "") {
        token := GoogleOAuth.GetAccessToken()
        response := HttpClient.Request(
            "GET",
            "https://www.googleapis.com/drive/v3/about?fields=user(displayName,emailAddress)",
            Map(
                "Authorization", "Bearer " token,
                "Accept", "application/json"
            ),
            "",
            10000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("Google Drive authentication failed.")

        return true
    }

    ValidateConnection() {
        return this.Connect()
    }

    GetTarget() {
        return AppState.CloudSyncTarget
    }

    Download() {
        this.Connect()

        fileId := Trim(AppState.CloudSyncTarget)
        if fileId == "" {
            fileId := this._FindFileId()
            if fileId == "" {
                return Map("exists", false)
            }

            AppState.CloudSyncTarget := fileId
            this._PersistTarget()
        }

        url := "https://www.googleapis.com/drive/v3/files/" fileId "?alt=media"
        response := HttpClient.Request(
            "GET",
            url,
            Map(
                "Authorization", "Bearer " GoogleOAuth.GetAccessToken()
            ),
            "",
            15000
        )

        if response.status == 404
            return Map("exists", false)

        if !HttpClient.IsSuccess(response)
            throw Error("Google Drive download failed. HTTP " response.status)

        package := CloudSyncModel.Deserialize(response.body)
        if !CloudSyncModel.VerifyPackage(package)
            throw Error("The Google Drive file is not a valid CapsLock sync package.")

        metadata := this._GetMetadata(fileId)

        result := Map()
        result["exists"] := true
        result["text"] := response.body
        result["fingerprint"] := package["integrity"]["contentHash"]
        result["revision"] := package["revision"]["id"]
        result["providerRevision"] := metadata["version"]
        return result
    }

    Upload(packageText, fingerprint := "", expectedRevision := "") {
        this.Connect()

        fileId := Trim(AppState.CloudSyncTarget)
        if fileId == "" {
            metadata := Map()
            metadata["name"] := this.FileName
            metadata["mimeType"] := "application/json"

            createResponse := HttpClient.Request(
                "POST",
                "https://www.googleapis.com/drive/v3/files?fields=id,name",
                Map(
                    "Authorization", "Bearer " GoogleOAuth.GetAccessToken(),
                    "Content-Type", "application/json"
                ),
                Json.Stringify(metadata, false),
                15000
            )

            if !HttpClient.IsSuccess(createResponse)
                throw Error("Could not create the Google Drive sync file.")

            created := Json.Parse(createResponse.body)
            fileId := created.Get("id", "")
            if fileId == ""
                throw Error("Google Drive did not return a file ID.")

            AppState.CloudSyncTarget := fileId
            this._PersistTarget()
        }

        ; Drive v3 exposes a monotonically increasing file version, but the
        ; upload API does not document an equivalent atomic compare-and-write
        ; parameter. Re-check the version immediately before the upload.
        if expectedRevision != "" {
            currentMetadata := this._GetMetadata(fileId)
            if !IsObject(currentMetadata)
                throw Error("Could not revalidate the Google Drive sync file before upload.")

            currentVersion := currentMetadata.Get("version", "")
            if currentVersion == "" || currentVersion != expectedRevision
                throw Error("The Google Drive sync file changed concurrently.")
        }

        url := "https://www.googleapis.com/upload/drive/v3/files/" fileId "?uploadType=media"
        response := HttpClient.Request(
            "PATCH",
            url,
            Map(
                "Authorization", "Bearer " GoogleOAuth.GetAccessToken(),
                "Content-Type", "application/json"
            ),
            packageText,
            15000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("Google Drive upload failed. HTTP " response.status)

        package := CloudSyncModel.Deserialize(packageText)
        metadata := this._GetMetadata(fileId)

        result := Map()
        result["ok"] := true
        result["fingerprint"] := fingerprint != ""
            ? fingerprint
                : package["integrity"]["contentHash"]
        result["revision"] := package["revision"]["id"]
        result["providerRevision"] := metadata["version"]
        return result
    }

    Disconnect() {
        return true
    }

    _FindFileId() {
        query := UriEncode("name='" this.FileName "' and trashed=false")
        url := "https://www.googleapis.com/drive/v3/files?q=" query "&spaces=drive&pageSize=1&fields=files(id,name)"
        response := HttpClient.Request(
            "GET",
            url,
            Map(
                "Authorization", "Bearer " GoogleOAuth.GetAccessToken()
            ),
            "",
            10000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("Google Drive target discovery failed.")

        data := Json.Parse(response.body)
        if !IsObject(data) || !data.Has("files")
            return ""

        files := data["files"]
        if !(files is Array) || files.Length == 0
            return ""

        return files[1].Get("id", "")
    }

    _GetMetadata(fileId) {
        url := "https://www.googleapis.com/drive/v3/files/" fileId "?fields=id,name,version,modifiedTime"
        response := HttpClient.Request(
            "GET",
            url,
            Map(
                "Authorization", "Bearer " GoogleOAuth.GetAccessToken()
            ),
            "",
            10000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("Google Drive version lookup failed. HTTP " response.status)

        try {
            metadata := Json.Parse(response.body)
        } catch as err {
            throw Error("Google Drive returned invalid file metadata: " err.Message)
        }

        if !IsObject(metadata) || !metadata.Has("version") || metadata["version"] == ""
            throw Error("Google Drive did not return a file version.")

        return metadata
    }

    _PersistTarget() {
        try IniWrite(
            AppState.CloudSyncTarget,
            AppState.ConfigFile,
            "CloudSync",
            "target"
        )
        catch {
        }
    }
}
