#Requires AutoHotkey v2.0

class GitHubGistProvider extends CloudSyncProvider {
    Name := "gist"
    static ApiBase := "https://api.github.com"
    static FileName := "capslock-sync.json"

    Connect(config := "") {
        token := CloudSyncCredentials.Get("gist", "token", "")
        if token == ""
            throw Error("GitHub Gist access token is not configured.")

        response := HttpClient.Request(
            "GET",
            this.ApiBase "/user",
            this._Headers(token),
            "",
            10000
        )

        if !HttpClient.IsSuccess(response)
            throw Error(this._ErrorMessage(response, "GitHub authentication failed."))

        return true
    }

    ValidateConnection() {
        this.Connect()

        if AppState.CloudSyncTarget == ""
            return true

        response := this._GetGist(AppState.CloudSyncTarget)
        return HttpClient.IsSuccess(response)
    }

    GetTarget() {
        return AppState.CloudSyncTarget
    }

    Download() {
        if AppState.CloudSyncTarget == ""
            return {exists: false}

        response := this._GetGist(AppState.CloudSyncTarget)

        if response.status == 404
            throw Error("The configured GitHub Gist could not be found.")

        if !HttpClient.IsSuccess(response)
            throw Error(this._ErrorMessage(response, "GitHub Gist download failed."))

        gist := this._ParseJson(response.body)
        if !IsObject(gist) || !gist.Has("files")
            throw Error("GitHub returned an invalid Gist response.")

        files := gist["files"]
        if !(files is Map) || !files.Has(this.FileName)
            return {exists: false}

        fileInfo := files[this.FileName]
        content := fileInfo.Has("content") ? String(fileInfo["content"]) : ""

        if fileInfo.Has("truncated") && fileInfo["truncated"] {
            rawUrl := fileInfo.Get("raw_url", "")
            if rawUrl == ""
                throw Error("GitHub returned truncated Gist content without a raw URL.")

            rawResponse := HttpClient.Request(
                "GET",
                rawUrl,
                this._Headers(),
                "",
                15000
            )

            if !HttpClient.IsSuccess(rawResponse)
                throw Error("GitHub Gist raw file download failed.")

            content := rawResponse.body
        }

        package := CloudSyncModel.Deserialize(content)
        if !IsObject(package) || !CloudSyncModel.VerifyPackage(package)
            throw Error("The GitHub Gist does not contain a valid CapsLock sync package.")

        fingerprint := package["integrity"]["contentHash"]
        revision := package["revision"]["id"]

        return {
            exists: true,
            text: content,
            fingerprint: fingerprint,
            revision: revision
        }
    }

    Upload(packageText, fingerprint := "", expectedRevision := "") {
        token := CloudSyncCredentials.Get("gist", "token", "")
        if token == ""
            throw Error("GitHub Gist access token is not configured.")

        body := Map()
        files := Map()
        file := Map()
        file["content"] := String(packageText)
        files[this.FileName] := file
        body["files"] := files

        if AppState.CloudSyncTarget == "" {
            body["description"] := "CapsLock- Cloud Sync"
            body["public"] := false

            response := HttpClient.Request(
                "POST",
                this.ApiBase "/gists",
                this._Headers(token),
                Json.Stringify(body, false),
                15000
            )

            if response.status != 201
                throw Error(this._ErrorMessage(response, "Could not create GitHub Gist."))

            gist := this._ParseJson(response.body)
            if !IsObject(gist) || !gist.Has("id")
                throw Error("GitHub did not return a Gist ID.")

            AppState.CloudSyncTarget := String(gist["id"])
            this._PersistTarget()
        } else {
            response := HttpClient.Request(
                "PATCH",
                this.ApiBase "/gists/" AppState.CloudSyncTarget,
                this._Headers(token),
                Json.Stringify(body, false),
                15000
            )

            if response.status == 404
                throw Error("The configured GitHub Gist no longer exists.")

            if !HttpClient.IsSuccess(response)
                throw Error(this._ErrorMessage(response, "Could not update GitHub Gist."))
        }

        package := CloudSyncModel.Deserialize(packageText)
        revision := IsObject(package) && CloudSyncModel.VerifyPackage(package)
            ? package["revision"]["id"]
            : ""

        return {
            ok: true,
            fingerprint: fingerprint != "" ? fingerprint : (
                IsObject(package) && package.Has("integrity")
                    ? package["integrity"]["contentHash"]
                    : ""
            ),
            revision: revision
        }
    }

    Disconnect() {
        return true
    }

    _GetGist(id) {
        token := CloudSyncCredentials.Get("gist", "token", "")
        return HttpClient.Request(
            "GET",
            this.ApiBase "/gists/" id,
            this._Headers(token),
            "",
            10000
        )
    }

    _Headers(token := "") {
        headers := Map()
        headers["Accept"] := "application/vnd.github+json"
        headers["User-Agent"] := "CapsLock-CloudSync"
        headers["X-GitHub-Api-Version"] := "2026-03-10"

        if token != ""
            headers["Authorization"] := "Bearer " token

        return headers
    }

    _ParseJson(text) {
        try
            return Json.Parse(text)
        catch
            return ""
    }

    _ErrorMessage(response, fallback) {
        try {
            error := Json.Parse(response.body)
            if IsObject(error) && error.Has("message")
                return String(error["message"])
        } catch {
        }

        return fallback " HTTP " response.status
    }

    _PersistTarget() {
        try {
            IniWrite(
                AppState.CloudSyncTarget,
                AppState.ConfigFile,
                "CloudSync",
                "target"
            )
        } catch {
        }
    }
}
