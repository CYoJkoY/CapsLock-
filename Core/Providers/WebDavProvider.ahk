#Requires AutoHotkey v2.0

class WebDavProvider extends CloudSyncProvider {
    Name := "webdav"

    Connect(config := "") {
        url := this._Url()
        if url == ""
            throw Error("WebDAV URL is not configured.")

        response := HttpClient.Request(
            "PROPFIND",
            this._BaseUrl(),
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

    Upload(packageText, fingerprint := "", expectedRevision := "") {
        this.Connect()
        this._EnsureParentCollection()

        headers := this._Headers()
        if expectedRevision != "" {
            etag := Trim(expectedRevision)
            ; RFC 7232: If-Match requires a quoted entity-tag; 
            ; quote it if the server returns one bare.
            if !InStr(etag, '"') && !InStr(etag, "W/")
                etag := '"' etag '"'
            headers["If-Match"] := etag
        }

        response := HttpClient.Request(
            "PUT",
            this._Url(),
            headers,
            packageText,
            15000
        )

        if response.status == 412
            throw Error("The WebDAV sync target changed concurrently.")

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

    ; WebDAV PUT doesn't create parent collections automatically,
    ; so a direct PUT to a path with subdirectories fails with 409/404.
    ; 405 = parent collection already exists, 409 = an intermediate level is  missing 
    ; — both are safe to ignore;
    ; the real outcome is decided by the following PUT.
    _EnsureParentCollection() {
        url := this._Url()
        base := this._BaseUrl()
        parent := SubStr(url, 1, InStr(url, "/", , -1) - 1)

        if parent == "" || parent == base || parent == url
            return

        try
            HttpClient.Request("MKCOL", parent, this._Headers(), "", 10000)
        catch {
        }
    }

    _BaseUrl() {
        return RTrim(Trim(AppState.CloudSyncWebDavUrl), "/")
    }

    _Url() {
        base := this._BaseUrl()
        path := Trim(AppState.CloudSyncWebDavPath, "/")
        if base == ""
            return ""

        encodedPath := path == ""
            ? "capslock-sync.json"
            : UriEncodePath(path)

        return base "/" encodedPath
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
