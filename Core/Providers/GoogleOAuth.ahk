#Requires AutoHotkey v2.0

class GoogleOAuth {
    static Active := false
    static ServerSocket := 0
    static CodeVerifier := ""
    static StateToken := ""
    static RedirectUri := ""
    static ClientId := ""

    static Authorize(*) {
        if this.Active
            return false

        clientId := Trim(AppState.CloudSyncGoogleClientId)
        if clientId == ""
            throw Error("Google OAuth client ID is not configured.")

        this._CloseServer()

        try {
            this._StartServer()

            this.ClientId := clientId
            this.CodeVerifier := Base64EncodeBuffer(RandomBytes(32), 32, true)
            this.StateToken := Base64EncodeBuffer(RandomBytes(24), 24, true)

            challenge := Base64EncodeBuffer(
                Sha256Bytes(this.CodeVerifier),
                32,
                true
            )

            params := Map()
            params["client_id"] := clientId
            params["redirect_uri"] := this.RedirectUri
            params["response_type"] := "code"
            params["scope"] := "https://www.googleapis.com/auth/drive.file"
            params["access_type"] := "offline"
            params["prompt"] := "consent"
            params["state"] := this.StateToken
            params["code_challenge"] := challenge
            params["code_challenge_method"] := "S256"

            url := "https://accounts.google.com/o/oauth2/v2/auth?" FormUrlEncode(params)

            this.Active := true
            SetTimer(GoogleOAuthPollTimer, 250)
            Run(url)
            return true
        } catch {
            this._CloseServer()
            this.Active := false
            throw
        }
    }

    static GetAccessToken() {
        accessToken := CloudSyncCredentials.Get("google", "accessToken", "")
        expiresAt := CloudSyncCredentials.Get("google", "expiresAt", "")

        if accessToken != "" && expiresAt != "" {
            try {
                if DateDiff(A_NowUTC, expiresAt, "Seconds") > 60
                    return accessToken
            } catch {
            }
        }

        refreshToken := CloudSyncCredentials.Get("google", "refreshToken", "")
        if refreshToken != ""
            return this.RefreshAccessToken()

        throw Error("Google Drive authorization is not configured.")
    }

    static RefreshAccessToken() {
        clientId := Trim(AppState.CloudSyncGoogleClientId)
        refreshToken := CloudSyncCredentials.Get("google", "refreshToken", "")

        if clientId == "" || refreshToken == ""
            throw Error("Google Drive refresh credentials are missing.")

        params := Map()
        params["client_id"] := clientId
        params["refresh_token"] := refreshToken
        params["grant_type"] := "refresh_token"

        response := HttpClient.Request(
            "POST",
            "https://oauth2.googleapis.com/token",
            Map("Content-Type", "application/x-www-form-urlencoded"),
            FormUrlEncode(params),
            15000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("Google token refresh failed. Re-authorization may be required.")

        token := Json.Parse(response.body)
        accessToken := token.Get("access_token", "")
        expiresIn := token.Get("expires_in", 3600)

        if accessToken == ""
            throw Error("Google did not return an access token.")

        expiresAt := DateAdd(A_NowUTC, Integer(expiresIn), "Seconds")
        CloudSyncCredentials.Set("google", "accessToken", accessToken)
        CloudSyncCredentials.Set("google", "expiresAt", expiresAt)

        return accessToken
    }

    static Disconnect() {
        CloudSyncCredentials.Delete("google")
        this._CloseServer()
        this.Active := false
        return true
    }

    static _Poll(*) {
        if !this.Active
            return

        client := DllCall(
            "ws2_32\accept",
            "Ptr", this.ServerSocket,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr"
        )

        if client == 0 || client == -1
            return

        try {
            mybuffer := Buffer(8192, 0)
            received := DllCall(
                "ws2_32\recv",
                "Ptr", client,
                "Ptr", mybuffer.Ptr,
                "Int", mybuffer.Size - 1,
                "Int", 0,
                "Int"
            )

            if received <= 0
                return

            request := StrGet(buffer, received, "UTF-8")
            if !RegExMatch(
                request,
                "m)^GET /oauth2callback\?([^ ]+) HTTP/",
                &match
            ) {
                this._SendBrowserResponse(client, false)
                return
            }

            query := this._ParseQuery(match[1])
            code := query.Get("code", "")
            returnedState := query.Get("state", "")
            myerror := query.Get("error", "")

            if returnedState == "" || returnedState != this.StateToken {
                this._SendBrowserResponse(client, false)
                this._Finish(false, "Google OAuth state validation failed.")
                return
            }

            if myerror != "" {
                this._SendBrowserResponse(client, false)
                this._Finish(false, "Google authorization was not completed: " myerror)
                return
            }

            if code == "" {
                this._SendBrowserResponse(client, false)
                this._Finish(false, "Google did not return an authorization code.")
                return
            }

            this._SendBrowserResponse(client, true)
            this._ExchangeCode(code)
        } catch as err {
            this._SendBrowserResponse(client, false)
            this._Finish(false, err.Message)
        } finally {
            DllCall("ws2_32\closesocket", "Ptr", client)
        }
    }

    static _ExchangeCode(code) {
        params := Map()
        params["client_id"] := this.ClientId
        params["code"] := code
        params["code_verifier"] := this.CodeVerifier
        params["redirect_uri"] := this.RedirectUri
        params["grant_type"] := "authorization_code"

        response := HttpClient.Request(
            "POST",
            "https://oauth2.googleapis.com/token",
            Map("Content-Type", "application/x-www-form-urlencoded"),
            FormUrlEncode(params),
            15000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("Google authorization code exchange failed.")

        token := Json.Parse(response.body)
        accessToken := token.Get("access_token", "")
        refreshToken := token.Get("refresh_token", "")
        expiresIn := token.Get("expires_in", 3600)

        if accessToken == ""
            throw Error("Google did not return an access token.")

        CloudSyncCredentials.Set("google", "accessToken", accessToken)
        CloudSyncCredentials.Set(
            "google",
            "expiresAt",
            DateAdd(A_NowUTC, Integer(expiresIn), "Seconds")
        )

        if refreshToken != ""
            CloudSyncCredentials.Set("google", "refreshToken", refreshToken)

        this._Finish(true, "Google Drive authorization completed successfully.")
    }

    static _Finish(success, message) {
        SetTimer(GoogleOAuthPollTimer, 0)
        this._CloseServer()
        this.Active := false
        this.CodeVerifier := ""
        this.StateToken := ""
        this.RedirectUri := ""

        if success {
            AppState.CloudSyncState := "connected"
            CloudSyncState.Set("Sync", "state", "connected")
        }

        ShowToolTip(
            success
                ? Lang("MSG_CLOUD_SYNC_CONNECTED", message)
                : Lang("MSG_CLOUD_SYNC_AUTH_FAILED", message),
            success ? 2200 : 3000
        )
    }

    static _StartServer() {
        wsa := Buffer(400, 0)
        status := DllCall(
            "ws2_32\WSAStartup",
            "UShort", 0x0202,
            "Ptr", wsa.Ptr,
            "Int"
        )
        if status != 0
            throw Error("Winsock initialization failed.")

        sock := DllCall(
            "ws2_32\socket",
            "Int", 2,
            "Int", 1,
            "Int", 6,
            "Ptr"
        )
        if sock == 0 || sock == -1
            throw Error("Could not create the Google OAuth callback socket.")

        address := Buffer(16, 0)
        NumPut(
            "UShort",
            DllCall("ws2_32\htons", "UShort", 2, "UShort"),
            address,
            0
        )
        NumPut(
            "UShort",
            DllCall("ws2_32\htons", "UShort", 0, "UShort"),
            address,
            2
        )
        NumPut(
            "UInt",
            DllCall("ws2_32\inet_addr", "AStr", "127.0.0.1", "UInt"),
            address,
            4
        )

        if DllCall(
            "ws2_32\bind",
            "Ptr", sock,
            "Ptr", address.Ptr,
            "Int", 16,
            "Int"
        ) != 0 {
            DllCall("ws2_32\closesocket", "Ptr", sock)
            throw Error("Could not bind the Google OAuth callback socket.")
        }

        if DllCall("ws2_32\listen", "Ptr", sock, "Int", 1, "Int") != 0 {
            DllCall("ws2_32\closesocket", "Ptr", sock)
            throw Error("Could not listen on the Google OAuth callback socket.")
        }

        getsockname := Buffer(16, 0)
        nameLength := 16
        if DllCall(
            "ws2_32\getsockname",
            "Ptr", sock,
            "Ptr", getsockname.Ptr,
            "Int*", &nameLength,
            "Int"
        ) != 0 {
            DllCall("ws2_32\closesocket", "Ptr", sock)
            throw Error("Could not determine the OAuth callback port.")
        }

        port := DllCall(
            "ws2_32\ntohs",
            "UShort",
            NumGet(getsockname, 2, "UShort"),
            "UShort"
        )

        nonBlocking := 1
        if DllCall(
            "ws2_32\ioctlsocket",
            "Ptr", sock,
            "UInt", 0x8004667E,
            "UInt*", &nonBlocking,
            "Int"
        ) != 0 {
            DllCall("ws2_32\closesocket", "Ptr", sock)
            throw Error("Could not configure the OAuth callback socket.")
        }

        this.ServerSocket := sock
        this.RedirectUri := "http://127.0.0.1:" port "/oauth2callback"
    }

    static _CloseServer() {
        if this.ServerSocket {
            DllCall("ws2_32\closesocket", "Ptr", this.ServerSocket)
            this.ServerSocket := 0
        }

        try DllCall("ws2_32\WSACleanup")
    }

    static _SendBrowserResponse(client, success) {
        html := success
            ? "<html><body><h2>CapsLock-</h2><p>Authorization completed. You can close this window.</p></body></html>"
            : "<html><body><h2>CapsLock-</h2><p>Authorization failed. Return to CapsLock- and retry.</p></body></html>"

        body := html
        crlf := Chr(13) Chr(10)
        response := "HTTP/1.1 200 OK" crlf
            . "Content-Type: text/html; charset=utf-8" crlf
            . "Connection: close" crlf
            . "Content-Length: " (StrPut(body, "UTF-8") - 1)
            . crlf crlf
            . body

        size := StrPut(response, "UTF-8")
        mybuffer := Buffer(size, 0)
        StrPut(response, mybuffer, "UTF-8")

        DllCall(
            "ws2_32\send",
            "Ptr", client,
            "Ptr", mybuffer.Ptr,
            "Int", size - 1,
            "Int", 0,
            "Int"
        )
    }

    static _ParseQuery(query) {
        result := Map()

        for pair in StrSplit(query, "&") {
            parts := StrSplit(pair, "=", , 2)
            if parts.Length != 2
                continue

            result[UriDecode(parts[1])] := UriDecode(parts[2])
        }

        return result
    }
}

GoogleOAuthPollTimer(*) {
    GoogleOAuth._Poll()
}

UriDecode(text) {
    text := StrReplace(String(text), "+", " ")
    result := ""
    i := 1
    len := StrLen(text)

    while i <= len {
        ch := SubStr(text, i, 1)
        if ch == "%" && i + 2 <= len {
            hex := SubStr(text, i + 1, 2)
            if RegExMatch(hex, "^[0-9A-Fa-f]{2}$") {
                result .= Chr("0x" hex)
                i += 3
                continue
            }
        }

        result .= ch
        i++
    }

    return result
}
