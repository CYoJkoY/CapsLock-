#Requires AutoHotkey v2.0

class OneDriveOAuth {
    static Active := false
    static DeviceCode := ""
    static ClientId := ""
    static IntervalSeconds := 5
    static ExpiresAt := 0

    static Authorize(*) {
        if this.Active
            return true

        clientId := Trim(AppState.CloudSyncOneDriveClientId)
        tenant := Trim(AppState.CloudSyncOneDriveTenant)
        if clientId == ""
            throw Error("OneDrive client ID is not configured.")
        if tenant == ""
            tenant := "common"

        fields := Map()
        fields["client_id"] := clientId
        fields["scope"] := "Files.ReadWrite offline_access openid profile"

        response := HttpClient.Request(
            "POST",
            "https://login.microsoftonline.com/" tenant "/oauth2/v2.0/devicecode",
            Map("Content-Type", "application/x-www-form-urlencoded"),
            FormUrlEncode(fields),
            15000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("OneDrive device authorization request failed.")

        data := Json.Parse(response.body)
        this.DeviceCode := data.Get("device_code", "")
        this.ClientId := clientId
        this.IntervalSeconds := Max(
            5,
            Integer(data.Get("interval", 5))
        )
        this.ExpiresAt := DllCall("GetTickCount64", "UInt64") + Integer(data.Get("expires_in", 900)) * 1000

        if this.DeviceCode == ""
            throw Error("Microsoft did not return a device code.")

        message := data.Get(
            "message",
            "Open the Microsoft verification page and enter the displayed code."
        )
        verificationUrl := data.Get(
            "verification_uri_complete",
            data.Get("verification_uri", "")
        )

        if verificationUrl != ""
            Run(verificationUrl)

        MsgBox(
            message,
            "OneDrive authorization",
            "Iconi T1"
        )

        this.Active := true
        SetTimer(OneDriveOAuthPollTimer, this.IntervalSeconds * 1000)
        return true
    }

    static GetAccessToken() {
        accessToken := CloudSyncCredentials.Get("onedrive", "accessToken", "")
        expiresAt := CloudSyncCredentials.Get("onedrive", "expiresAt", "")

        if accessToken != "" && expiresAt != "" {
            try {
                if DateDiff(A_NowUTC, expiresAt, "Seconds") > 60
                    return accessToken
            } catch {
            }
        }

        refreshToken := CloudSyncCredentials.Get("onedrive", "refreshToken", "")
        if refreshToken == ""
            throw Error("OneDrive authorization is not configured.")

        return this.RefreshAccessToken()
    }

    static RefreshAccessToken() {
        tenant := Trim(AppState.CloudSyncOneDriveTenant)
        if tenant == ""
            tenant := "common"

        refreshToken := CloudSyncCredentials.Get(
            "onedrive",
            "refreshToken",
            ""
        )
        clientId := Trim(AppState.CloudSyncOneDriveClientId)

        fields := Map()
        fields["client_id"] := clientId
        fields["refresh_token"] := refreshToken
        fields["grant_type"] := "refresh_token"
        fields["scope"] := "Files.ReadWrite offline_access openid profile"

        response := HttpClient.Request(
            "POST",
            "https://login.microsoftonline.com/" tenant "/oauth2/v2.0/token",
            Map("Content-Type", "application/x-www-form-urlencoded"),
            FormUrlEncode(fields),
            15000
        )

        if !HttpClient.IsSuccess(response)
            throw Error("OneDrive token refresh failed. Re-authorization may be required.")

        token := Json.Parse(response.body)
        accessToken := token.Get("access_token", "")
        expiresIn := token.Get("expires_in", 3600)

        if accessToken == ""
            throw Error("Microsoft did not return an access token.")

        CloudSyncCredentials.Set("onedrive", "accessToken", accessToken)
        CloudSyncCredentials.Set(
            "onedrive",
            "expiresAt",
            DateAdd(A_NowUTC, Integer(expiresIn), "Seconds")
        )

        if token.Has("refresh_token")
            CloudSyncCredentials.Set(
                "onedrive",
                "refreshToken",
                token["refresh_token"]
            )

        return accessToken
    }

    static _Poll(*) {
        if !this.Active
            return

        if DllCall("GetTickCount64", "UInt64") >= this.ExpiresAt {
            this._Finish(false, "OneDrive authorization code expired.")
            return
        }

        tenant := Trim(AppState.CloudSyncOneDriveTenant)
        if tenant == ""
            tenant := "common"

        fields := Map()
        fields["client_id"] := this.ClientId
        fields["device_code"] := this.DeviceCode
        fields["grant_type"] := "urn:ietf:params:oauth:grant-type:device_code"
        fields["scope"] := "Files.ReadWrite offline_access openid profile"

        response := HttpClient.Request(
            "POST",
            "https://login.microsoftonline.com/" tenant "/oauth2/v2.0/token",
            Map("Content-Type", "application/x-www-form-urlencoded"),
            FormUrlEncode(fields),
            15000
        )

        if response.status == 200 {
            token := Json.Parse(response.body)
            CloudSyncCredentials.Set(
                "onedrive",
                "accessToken",
                token.Get("access_token", "")
            )
            CloudSyncCredentials.Set(
                "onedrive",
                "expiresAt",
                DateAdd(
                    A_NowUTC,
                    Integer(token.Get("expires_in", 3600)),
                    "Seconds"
                )
            )

            if token.Has("refresh_token")
                CloudSyncCredentials.Set(
                    "onedrive",
                    "refreshToken",
                    token["refresh_token"]
                )

            this._Finish(true, "OneDrive authorization completed successfully.")
            return
        }

        try {
            errorData := Json.Parse(response.body)
            errorCode := errorData.Get("error", "")
            if errorCode == "authorization_pending"
                return

            if errorCode == "slow_down" {
                this.IntervalSeconds += 5
                SetTimer(
                    OneDriveOAuthPollTimer,
                    this.IntervalSeconds * 1000
                )
                return
            }

            if errorCode == "authorization_declined"
                return this._Finish(false, "OneDrive authorization was declined.")

            if errorCode == "expired_token"
                return this._Finish(false, "OneDrive authorization code expired.")
        } catch {
        }

        this._Finish(false, "OneDrive authorization failed.")
    }

    static _Finish(success, message) {
        SetTimer(OneDriveOAuthPollTimer, 0)
        this.Active := false
        this.DeviceCode := ""
        this.ClientId := ""
        this.ExpiresAt := 0

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

    static Disconnect() {
        SetTimer(OneDriveOAuthPollTimer, 0)
        this.Active := false
        this.DeviceCode := ""
        return true
    }
}

OneDriveOAuthPollTimer(*) {
    OneDriveOAuth._Poll()
}
