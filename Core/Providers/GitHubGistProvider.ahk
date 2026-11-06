#Requires AutoHotkey v2.0

class GitHubGistProvider extends CloudSyncProvider {
    Name := "gist"
    static ApiBase := "https://api.github.com"
    FileName := "capslock-sync.json"

    Connect(config := "") {
        token := Trim(CloudSyncCredentials.Get("gist", "token", ""))
        if token == ""
            throw Error("GitHub Gist access token is not configured.")

        response := HttpClient.Request(
            "GET",
            GitHubGistProvider.ApiBase "/user",
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

        target := Trim(AppState.CloudSyncTarget)
        if target == "" {
            response := HttpClient.Request(
                "GET",
                GitHubGistProvider.ApiBase "/gists?per_page=1",
                this._Headers(Trim(CloudSyncCredentials.Get("gist", "token", ""))),
                "",
                10000
            )

            if !HttpClient.IsSuccess(response)
                throw Error(this._ErrorMessage(response, "GitHub Gist permission validation failed."))

            return true
        }

        response := this._GetGist(target)
        if response.status == 404
            throw Error("The configured GitHub Gist could not be found.")

        if !HttpClient.IsSuccess(response)
            throw Error(this._ErrorMessage(response, "GitHub Gist validation failed."))

        return true
    }

    GetTarget() {
        return Trim(AppState.CloudSyncTarget)
    }

    Download() {
        target := Trim(AppState.CloudSyncTarget)
        if target == ""
            return Map("exists", false)

        response := this._GetGist(target)

        if response.status == 404
            throw Error("The configured GitHub Gist could not be found.")

        if !HttpClient.IsSuccess(response)
            throw Error(this._ErrorMessage(response, "GitHub Gist download failed."))

        gist := this._ParseJson(response.body)
        if !IsObject(gist) || !gist.Has("files")
            throw Error("GitHub returned an invalid Gist response.")

        files := gist["files"]
        if !(files is Map) || !files.Has(this.FileName)
            return Map("exists", false)

        fileInfo := files[this.FileName]
        content := fileInfo.Has("content") ? String(fileInfo["content"]) : ""
        providerRevision := this._Header(response.headers, "ETag")

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

            ; The raw URL is a separate request from the Gist API response.
            ; Confirm the Gist did not change between those reads.
            if providerRevision == ""
                throw Error("GitHub did not return an ETag for the truncated Gist.")

            current := this._GetGist(target)
            currentRevision := this._Header(current.headers, "ETag")
            if !HttpClient.IsSuccess(current) || currentRevision == ""
                throw Error("Could not verify the truncated Gist after downloading it.")

            if currentRevision != providerRevision
                throw Error("The GitHub Gist changed while it was being downloaded.")
        }

        package := CloudSyncModel.Deserialize(content)
        if !IsObject(package) || !CloudSyncModel.VerifyPackage(package)
            throw Error("The GitHub Gist does not contain a valid CapsLock sync package.")

        fingerprint := package["integrity"]["contentHash"]
        revision := package["revision"]["id"]

        result := Map()
        result["exists"] := true
        result["text"] := content
        result["fingerprint"] := fingerprint
        result["revision"] := revision
        result["providerRevision"] := providerRevision
        return result
    }

    Upload(packageText, fingerprint := "", expectedRevision := "") {
        token := Trim(CloudSyncCredentials.Get("gist", "token", ""))
        if token == ""
            throw Error("GitHub Gist access token is not configured.")

        target := Trim(AppState.CloudSyncTarget)
        body := Map()
        files := Map()
        myfile := Map()
        myfile["content"] := String(packageText)
        files[this.FileName] := myfile
        body["files"] := files

        if target == "" {
            body["description"] := "CapsLock- Cloud Sync"
            body["public"] := false

            response := HttpClient.Request(
                "POST",
                GitHubGistProvider.ApiBase "/gists",
                this._Headers(token),
                Json.Stringify(body, false),
                15000
            )

            if response.status != 201
                throw Error(this._ErrorMessage(response, "Could not create GitHub Gist."))

            gist := this._ParseJson(response.body)
            if !IsObject(gist) || !gist.Has("id")
                throw Error("GitHub did not return a Gist ID.")

            this.PersistTarget(gist["id"])
        } else {
            ; GitHub Gist update has no documented server-side SHA compare-and-write
            ; parameter. Revalidate the resource immediately before PATCH when the
            ; last observed HTTP ETag is available.
            if expectedRevision != "" {
                current := this._GetGist(target)
                if !HttpClient.IsSuccess(current)
                    throw Error("Could not revalidate the configured GitHub Gist before upload.")

                currentRevision := this._Header(current.headers, "ETag")
                if currentRevision == "" || currentRevision != expectedRevision
                    throw Error("The GitHub Gist changed concurrently.")
            }

            response := HttpClient.Request(
                "PATCH",
                GitHubGistProvider.ApiBase "/gists/" target,
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

        providerRevision := this._Header(response.headers, "ETag")
        if providerRevision == "" && Trim(AppState.CloudSyncTarget) != "" {
            try {
                refreshed := this._GetGist(Trim(AppState.CloudSyncTarget))
                if HttpClient.IsSuccess(refreshed)
                    providerRevision := this._Header(refreshed.headers, "ETag")
            } catch {
            }
        }

        result := Map()
        result["ok"] := true
        result["fingerprint"] := fingerprint != "" ? fingerprint : (
            IsObject(package) && package.Has("integrity")
                ? package["integrity"]["contentHash"]
                : ""
        )
        result["revision"] := revision
        result["providerRevision"] := providerRevision
        return result
    }

    Disconnect() {
        return true
    }

    _GetGist(id) {
        token := Trim(CloudSyncCredentials.Get("gist", "token", ""))
        return HttpClient.Request(
            "GET",
            GitHubGistProvider.ApiBase "/gists/" Trim(id),
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
        headers["Content-Type"] := "application/json"

        token := Trim(token)
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

    _Header(headersText, name) {
        pattern := "im)^\s*" RegExEscape(name) "\s*:\s*(.*?)\s*$"
        if RegExMatch(headersText, pattern, &match)
            return Trim(match[1])
        return ""
    }

    _ErrorMessage(response, fallback) {
        try {
            myerror := Json.Parse(response.body)
            if IsObject(myerror) && myerror.Has("message")
                return String(myerror["message"])
        } catch {
        }

        return fallback " HTTP " response.status
    }

}
