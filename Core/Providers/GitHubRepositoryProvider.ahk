#Requires AutoHotkey v2.0

class GitHubRepositoryProvider extends CloudSyncProvider {
    Name := "github"
    static ApiBase := "https://api.github.com"
    static FileName := "capslock-sync.json"

    Connect(config := "") {
        token := CloudSyncCredentials.Get("github", "token", "")
        if token == ""
            throw Error("GitHub repository access token is not configured.")

        owner := Trim(AppState.CloudSyncGitHubOwner)
        repo := Trim(AppState.CloudSyncGitHubRepository)
        if owner == "" || repo == ""
            throw Error("GitHub repository owner and repository are not configured.")

        response := HttpClient.Request(
            "GET",
            this.ApiBase "/repos/" owner "/" repo,
            this._Headers(token),
            "",
            10000
        )

        if !HttpClient.IsSuccess(response)
            throw Error(this._ErrorMessage(response, "GitHub repository validation failed."))

        return true
    }

    ValidateConnection() {
        this.Connect()
        return this.GetTarget() != ""
    }

    GetTarget() {
        return AppState.CloudSyncGitHubOwner "/" AppState.CloudSyncGitHubRepository "/" AppState.CloudSyncGitHubPath "@" AppState.CloudSyncGitHubBranch
    }

    Download() {
        this.Connect()

        path := AppState.CloudSyncGitHubPath
        branch := AppState.CloudSyncGitHubBranch
        owner := AppState.CloudSyncGitHubOwner
        repo := AppState.CloudSyncGitHubRepository

        url := this.ApiBase "/repos/" owner "/" repo "/contents/" UriEncodePath(path) "?ref=" UriEncode(branch)

        response := HttpClient.Request(
            "GET",
            url,
            this._Headers(CloudSyncCredentials.Get("github", "token", "")),
            "",
            10000
        )

        if response.status == 404
            return {exists: false}

        if !HttpClient.IsSuccess(response)
            throw Error(this._ErrorMessage(response, "GitHub repository download failed."))

        metadata := this._ParseJson(response.body)
        if !IsObject(metadata) || !metadata.Has("content")
            throw Error("GitHub returned an invalid repository file response.")

        content := Base64DecodeText(
            StrReplace(metadata["content"], Chr(10), ""),
            false
        )

        package := CloudSyncModel.Deserialize(content)
        if !CloudSyncModel.VerifyPackage(package)
            throw Error("The GitHub repository file is not a valid CapsLock sync package.")

        sha := metadata.Get("sha", "")
        return {
            exists: true,
            text: content,
            fingerprint: package["integrity"]["contentHash"],
            revision: package["revision"]["id"],
            providerRevision: sha
        }
    }

    Upload(packageText, fingerprint := "", expectedRevision := "") {
        this.Connect()

        token := CloudSyncCredentials.Get("github", "token", "")
        owner := AppState.CloudSyncGitHubOwner
        repo := AppState.CloudSyncGitHubRepository
        path := AppState.CloudSyncGitHubPath
        branch := AppState.CloudSyncGitHubBranch

        sha := expectedRevision
        if sha == "" {
            existing := this._GetFileMetadata(owner, repo, path, branch, token)
            if existing.status == 200 {
                metadata := this._ParseJson(existing.body)
                sha := IsObject(metadata) ? metadata.Get("sha", "") : ""
            } else if existing.status != 404 {
                throw Error(this._ErrorMessage(existing, "Could not inspect GitHub repository target."))
            }
        }

        body := Map()
        body["message"] := "Update CapsLock Cloud Sync"
        body["content"] := Base64EncodeText(packageText)
        body["branch"] := branch
        if sha != ""
            body["sha"] := sha

        response := HttpClient.Request(
            "PUT",
            this.ApiBase "/repos/" owner "/" repo "/contents/" UriEncodePath(path),
            this._Headers(token),
            Json.Stringify(body, false),
            15000
        )

        if response.status == 409
            throw Error("GitHub repository target changed concurrently.")

        if !HttpClient.IsSuccess(response)
            throw Error(this._ErrorMessage(response, "GitHub repository upload failed."))

        package := CloudSyncModel.Deserialize(packageText)
        newSha := ""
        try {
            result := this._ParseJson(response.body)
            if IsObject(result) && result.Has("content")
                newSha := result["content"].Get("sha", "")
        } catch {
        }

        return {
            ok: true,
            fingerprint: fingerprint != ""
                ? fingerprint
                : package["integrity"]["contentHash"],
            revision: package["revision"]["id"],
            providerRevision: newSha
        }
    }

    Disconnect() {
        return true
    }

    _GetFileMetadata(owner, repo, path, branch, token) {
        url := this.ApiBase "/repos/" owner "/" repo "/contents/" path "?ref=" UriEncode(branch)
        return HttpClient.Request(
            "GET",
            url,
            this._Headers(token),
            "",
            10000
        )
    }

    _Headers(token) {
        headers := Map()
        headers["Accept"] := "application/vnd.github+json"
        headers["User-Agent"] := "CapsLock-CloudSync"
        headers["X-GitHub-Api-Version"] := "2026-03-10"
        headers["Authorization"] := "Bearer " token
        headers["Content-Type"] := "application/json"
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
            myerror := Json.Parse(response.body)
            if IsObject(myerror) && myerror.Has("message")
                return String(myerror["message"])
        } catch {
        }

        return fallback " HTTP " response.status
    }
}
