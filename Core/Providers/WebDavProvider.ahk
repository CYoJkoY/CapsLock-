#Requires AutoHotkey v2.0

class WebDavProvider extends CloudSyncProvider {
    Name := "webdav"

    Connect(config := "") {
        url := this._Url()
        if url == ""
            throw Error("WebDAV URL is not configured.")

        response := HttpClient.Request(
            "PROPFIND",
            url,
            this._Headers(),
            "",
            10000
        )

        if response.status < 200 || response.status >= 400
            throw Error("WebDAV connection failed. HTTP " response.status)

        return true
    }

    ValidateConnection() {
        this.Connect()
        return true
    }

    GetTarget() {
        return this._Url()
    }

    Download() {
        this.Connect()

        response := HttpClient.Request(
            "GET",
            this._Url(),
            this._Headers(),
            "",
            15000
        )

        if response.status == 404
            return {exists: false}

        if !HttpClient.IsSuccess(response)
            throw Error("WebDAV download failed. HTTP " response.status)

        package := CloudSyncModel.Deserialize(response.body)
        if !CloudSyncModel.VerifyPackage(package)
            throw Error("The WebDAV file is not a valid CapsLock sync package.")

        return {
            exists: true,
            text: response.body,
            fingerprint: package["integrity"]["contentHash"],
            revision: package["revision"]["id"],
            providerRevision: this._Header(response.headers, "ETag")
        }
    }

    Upload(packageText, fingerprint := "") {
        this.Connect()

        response := HttpClient.Request(
            "PUT",
            this._Url(),
            this._Headers(),
            packageText,
            15000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("WebDAV upload failed. HTTP " response.status)

        package := CloudSyncModel.Deserialize(packageText)
        return {
            ok: true,
            fingerprint: fingerprint != ""
                ? fingerprint
                : package["integrity"]["contentHash"],
            revision: package["revision"]["id"],
            providerRevision: this._Header(response.headers, "ETag")
        }
    }

    Disconnect() {
        return true
    }

    _Url() {
        base := RTrim(Trim(AppState.CloudSyncWebDavUrl), "/")
        path := Trim(AppState.CloudSyncWebDavPath, "/")
        if base == ""
            return ""
        return path == "" ? base "/capslock-sync.json" : base "/" path
    }

    _Headers() {
        headers := Map()
        headers["User-Agent"] := "CapsLock-CloudSync"
        headers["Content-Type"] := "application/json"

        username := CloudSyncCredentials.Get("webdav", "username", "")
        password := CloudSyncCredentials.Get("webdav", "password", "")
        if username != "" {
            token := Base64EncodeText(username ":" password)
            headers["Authorization"] := "Basic " token
        }

        return headers
    }

    _Header(headersText, name) {
        pattern := "im)^\s*" RegExEscape(name) "\s*:\s*(.*?)\s*$"
        if RegExMatch(headersText, pattern, &match)
            return Trim(match[1])
        return ""
    }
}

RegExEscape(text) {
    result := String(text)
    return RegExReplace(result, "([\\.^$|(){}\[\]*+?])", "\$1")
}
