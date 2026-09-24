#Requires AutoHotkey v2.0

ShowCloudSyncSettings(*) {
    static currentGui := ""

    if IsObject(currentGui) {
        try {
            currentGui.Show()
            WinActivate("ahk_id " currentGui.Hwnd)
            return
        } catch {
            currentGui := ""
        }
    }

    myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", Lang("GUI_CLOUD_SYNC_TITLE", "Cloud Sync"))
    currentGui := myGui
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(
        myGui,
        "☁ " Lang("GUI_CLOUD_SYNC_TITLE", "Cloud Sync"),
        620
    )
    ThemeHelper.AddSubtitle(
        myGui,
        Lang(
            "GUI_CLOUD_SYNC_SUBTITLE",
            "Optional synchronization for CapsLock- settings and Quick Phrases."
        ),
        620
    )
    ThemeHelper.AddSeparator(myGui, 620)

    enabled := myGui.Add(
        "CheckBox",
        "w620 y+12 " ThemeHelper.GetCheckBoxOptions(),
        Lang("GUI_CLOUD_SYNC_ENABLE", "Enable Cloud Sync")
    )
    ThemeHelper.StyleCheckBox(enabled)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    providerLabel := myGui.AddText("w620 y+12", Lang("GUI_CLOUD_SYNC_PROVIDER", "Provider"))
    ThemeHelper.MarkDim(providerLabel)
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

    provider := myGui.Add(
        "ComboBox",
        "w620 y+6 Choose1 c" AppState.THEME_FG,
        [
            "GitHub Gist",
            "GitHub Private Repository",
            "Google Drive",
            "OneDrive",
            "WebDAV"
        ]
    )
    ThemeHelper.StyleComboBox(provider)

    ; --- Provider-specific fields ---
    gistTargetLabel := myGui.AddText("w620 y+12", Lang("GUI_CLOUD_SYNC_TARGET", "Target") " (Gist ID; leave blank to create automatically)")
    gistTarget := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(gistTarget)

    gistTokenLabel := myGui.AddText("w620 y+8", Lang("GUI_CLOUD_SYNC_GITHUB_TOKEN", "GitHub token"))
    gistToken := myGui.Add("Edit", "Password w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(gistToken)

    repoOwnerLabel := myGui.AddText("x16 y+12 w300", Lang("GUI_CLOUD_SYNC_GITHUB_OWNER", "GitHub owner"))
    repoNameLabel  := myGui.AddText("x326 yp w310", Lang("GUI_CLOUD_SYNC_GITHUB_REPOSITORY", "Repository"))

    repoOwner := myGui.Add("Edit", "x16 y+6 w300 r1 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(repoOwner)
    repoName := myGui.Add("Edit", "x326 yp w310 r1 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(repoName)

    repoBranchLabel := myGui.AddText("x16 y+8 w300", Lang("GUI_CLOUD_SYNC_GITHUB_BRANCH", "Branch"))
    repoPathLabel   := myGui.AddText("x326 yp w310", Lang("GUI_CLOUD_SYNC_GITHUB_PATH", "Path"))

    repoBranch := myGui.Add("Edit", "x16 y+6 w300 r1 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(repoBranch)
    repoPath := myGui.Add("Edit", "x326 yp w310 r1 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(repoPath)

    repoTokenLabel := myGui.AddText("x16 y+8 w620", Lang("GUI_CLOUD_SYNC_GITHUB_TOKEN", "GitHub token"))
    repoToken := myGui.Add("Edit", "Password x16 y+6 w620 r1 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(repoToken)

    googleClientLabel := myGui.AddText("w620 y+12", Lang("GUI_CLOUD_SYNC_GOOGLE_CLIENT_ID", "Google OAuth client ID"))
    googleClient := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(googleClient)

    googleTargetLabel := myGui.AddText("w620 y+8", Lang("GUI_CLOUD_SYNC_GOOGLE_TARGET", "Drive file ID") " (optional)")
    googleTarget := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(googleTarget)

    googleAuthorize := ThemeHelper.AddButton(
        myGui,
        "w150 y+10",
        "🔐 " Lang("GUI_CLOUD_SYNC_GOOGLE_AUTHORIZE", "Authorize Google"),
        "primary"
    )

    oneDriveClientLabel := myGui.AddText("w620 y+12", Lang("GUI_CLOUD_SYNC_ONEDRIVE_CLIENT_ID", "Microsoft client ID"))
    oneDriveClient := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(oneDriveClient)

    oneDriveTenantLabel := myGui.AddText("w620 y+8", Lang("GUI_CLOUD_SYNC_ONEDRIVE_TENANT", "Tenant"))
    oneDriveTenant := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(oneDriveTenant)

    oneDrivePathLabel := myGui.AddText("w620 y+8", Lang("GUI_CLOUD_SYNC_ONEDRIVE_PATH", "OneDrive path"))
    oneDrivePath := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(oneDrivePath)

    oneDriveAuthorize := ThemeHelper.AddButton(
        myGui,
        "w160 y+10",
        "🔐 " Lang("GUI_CLOUD_SYNC_ONEDRIVE_AUTHORIZE", "Authorize OneDrive"),
        "primary"
    )

    webdavUrlLabel := myGui.AddText("w620 y+12", Lang("GUI_CLOUD_SYNC_WEBDAV_URL", "WebDAV URL"))
    webdavUrl := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(webdavUrl)

    webdavPathLabel := myGui.AddText("w620 y+8", Lang("GUI_CLOUD_SYNC_WEBDAV_PATH", "Remote path"))
    webdavPath := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(webdavPath)

    webdavUserLabel := myGui.AddText("w620 y+8", Lang("GUI_CLOUD_SYNC_WEBDAV_USERNAME", "Username"))
    webdavUser := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(webdavUser)

    webdavPasswordLabel := myGui.AddText("w620 y+8", Lang("GUI_CLOUD_SYNC_WEBDAV_PASSWORD", "Password"))
    webdavPassword := myGui.Add("Edit", "Password w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(webdavPassword)

    ; --- Shared fields ---
    deviceLabel := myGui.AddText("w620 y+12", Lang("GUI_CLOUD_SYNC_DEVICE_NAME", "Device name"))
    device := myGui.Add("Edit", "w620 r1 y+6 " ThemeHelper.GetEditOptions())
    ThemeHelper.StyleEdit(device)

    autoSync := myGui.Add(
        "CheckBox",
        "x16 y+12 w380 " ThemeHelper.GetCheckBoxOptions(),
        Lang("GUI_CLOUD_SYNC_AUTO", "Enable automatic synchronization")
    )
    ThemeHelper.StyleCheckBox(autoSync)

    interval := myGui.Add(
        "Edit",
        "x406 yp w90 r1 " ThemeHelper.GetEditOptions(),
        String(AppState.CloudSyncInterval)
    )
    ThemeHelper.StyleEdit(interval)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    minutesLabel := myGui.AddText("x504 yp+3", Lang("GUI_CLOUD_SYNC_MINUTES", "minutes"))
    ThemeHelper.MarkDim(minutesLabel)
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

    status := myGui.Add(
        "Text",
        "w620 y+12",
        CloudSyncCoordinator.GetStatusText()
    )

    lastSuccess := myGui.Add(
        "Text",
        "w620 y+6",
        Lang("GUI_CLOUD_SYNC_LAST_SUCCESS", "Last successful synchronization")
            ": " (AppState.CloudSyncLastSuccess != "" ? AppState.CloudSyncLastSuccess : "—")
    )

    saveBtn := ThemeHelper.AddButton(
        myGui,
        "Default x16 y+14 w90 h30",
        "✓ " Lang("GUI_SAVE", "Save"),
        "primary"
    )
    connectBtn := ThemeHelper.AddButton(
        myGui,
        "x114 yp w100 h30",
        Lang("GUI_CLOUD_SYNC_CONNECT", "Connect")
    )
    syncBtn := ThemeHelper.AddButton(
        myGui,
        "x222 yp w95 h30",
        "☁ " Lang("GUI_CLOUD_SYNC_SYNC_NOW", "Sync now")
    )
    resetBtn := ThemeHelper.AddButton(
        myGui,
        "x325 yp w80 h30",
        Lang("GUI_CLOUD_SYNC_RESET", "Reset"),
        "danger"
    )
    disconnectBtn := ThemeHelper.AddButton(
        myGui,
        "x413 yp w95 h30",
        Lang("GUI_CLOUD_SYNC_DISCONNECT", "Disconnect")
    )
    closeBtn := ThemeHelper.AddButton(
        myGui,
        "x516 yp w80 h30",
        Lang("GUI_FULL_CLOSE", "Close")
    )

    allProviderCtrls := [
        gistTargetLabel, gistTarget,
        gistTokenLabel, gistToken,
        repoOwnerLabel, repoOwner,
        repoNameLabel, repoName,
        repoBranchLabel, repoBranch,
        repoPathLabel, repoPath,
        repoTokenLabel, repoToken,
        googleClientLabel, googleClient,
        googleTargetLabel, googleTarget,
        googleAuthorize,
        oneDriveClientLabel, oneDriveClient,
        oneDriveTenantLabel, oneDriveTenant,
        oneDrivePathLabel, oneDrivePath,
        oneDriveAuthorize,
        webdavUrlLabel, webdavUrl,
        webdavPathLabel, webdavPath,
        webdavUserLabel, webdavUser,
        webdavPasswordLabel, webdavPassword
    ]

    ; One element = one "row"; controls within a row share the same baseline y
    rows := [
        [gistTargetLabel], [gistTarget],
        [gistTokenLabel], [gistToken],
        [repoOwnerLabel, repoNameLabel], [repoOwner, repoName],
        [repoBranchLabel, repoPathLabel], [repoBranch, repoPath],
        [repoTokenLabel], [repoToken],
        [googleClientLabel], [googleClient],
        [googleTargetLabel], [googleTarget],
        [googleAuthorize],
        [oneDriveClientLabel], [oneDriveClient],
        [oneDriveTenantLabel], [oneDriveTenant],
        [oneDrivePathLabel], [oneDrivePath],
        [oneDriveAuthorize],
        [webdavUrlLabel], [webdavUrl],
        [webdavPathLabel], [webdavPath],
        [webdavUserLabel], [webdavUser],
        [webdavPasswordLabel], [webdavPassword],
        [deviceLabel], [device],
        [autoSync, interval, minutesLabel],
        [status], [lastSuccess],
        [saveBtn, connectBtn, syncBtn, resetBtn, disconnectBtn, closeBtn]
    ]

    ; Per-row "gap from the previous row", one-to-one withrows
    gaps := [
        12, 6,   12, 6,   12, 6,   10, 6,   10, 6,
        12, 6,   10, 6,   12,
        12, 6,   10, 6,   10, 6,   12,
        12, 6,   10, 6,   10, 6,   10, 6,
        14, 6,   12,      12, 6,   14
    ]

    ; ---- geometry bootstrap ----
    ; AHK only finalizes control geometry (especially auto-wrapped Text heights)
    ; after the window exists, so create it hidden once before measuring.
    myGui.Show("w660 h600 Hide")
    provider.GetPos(, &providerY, , &providerH)
    providerAreaY := providerY + providerH + 12

    ; Sample in-row offsets AND control heights once, now that the window exists.
    rowOffsets := []
    rowHeights := []
    for row in rows {
        offsets := []
        heights := []
        row[1].GetPos(, &baseY)
        for ctrl in row {
            ctrl.GetPos(, &cy, , &ch)
            offsets.Push(cy - baseY)
            heights.Push(ch)
        }
        rowOffsets.Push(offsets)
        rowHeights.Push(heights)
    }

    Reflow(rows, gaps, startY) {
        y := startY
        for i, row in rows {
            visible := false
            for ctrl in row
                if ctrl.Visible {
                    visible := true
                    break
                }
            if !visible
                continue

            y += gaps[i]
            bottom := y
            for j, ctrl in row {
                ctrl.GetPos(&cx, &cy, &cw)
                ctrl.Move(cx, y + rowOffsets[i][j], cw, rowHeights[i][j])
                bottom := Max(bottom, y + rowOffsets[i][j] + rowHeights[i][j])
            }
            y := bottom
        }
        return y
    }

    SetRedraw(on) {
        try DllCall("user32\SendMessage", "ptr", myGui.Hwnd,
            "uint", 0x000B, "ptr", on ? 1 : 0, "ptr", 0, "ptr")
    }

    RepaintGui() {
        static RDW_INVALIDATE  := 0x0001
        static RDW_ERASE       := 0x0004
        static RDW_ALLCHILDREN := 0x0080
        static RDW_UPDATENOW   := 0x0100

        ; Force one synchronous repaint of the whole client area AND every
        ; child window. Hiding or moving controls in the same tick does not
        ; reliably invalidate the parent, leaving stale text on screen until
        ; something else (e.g. the mouse) triggers a paint.
        DllCall("user32\RedrawWindow", "ptr", myGui.Hwnd, "ptr", 0, "ptr", 0,
            "uint", RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW)
    }

    ProviderFields(recenter := false) {
        SetRedraw(false)  ; WM_SETREDRAW off

        try {
            for ctrl in allProviderCtrls
                ctrl.Visible := false

            switch provider.Text {
                case "GitHub Gist":
                    for ctrl in [gistTargetLabel, gistTarget, gistTokenLabel, gistToken]
                        ctrl.Visible := true
                case "GitHub Private Repository":
                    for ctrl in [
                        repoOwnerLabel, repoOwner, repoNameLabel, repoName,
                        repoBranchLabel, repoBranch, repoPathLabel, repoPath,
                        repoTokenLabel, repoToken
                    ]
                        ctrl.Visible := true
                case "Google Drive":
                    for ctrl in [googleClientLabel, googleClient, googleTargetLabel, googleTarget, googleAuthorize]
                        ctrl.Visible := true
                case "OneDrive":
                    for ctrl in [
                        oneDriveClientLabel, oneDriveClient, oneDriveTenantLabel,
                        oneDriveTenant, oneDrivePathLabel, oneDrivePath, oneDriveAuthorize
                    ]
                        ctrl.Visible := true
                case "WebDAV":
                    for ctrl in [
                        webdavUrlLabel, webdavUrl, webdavPathLabel, webdavPath,
                        webdavUserLabel, webdavUser, webdavPasswordLabel, webdavPassword
                    ]
                        ctrl.Visible := true
            }

            contentBottom := Reflow(rows, gaps, providerAreaY)
            winH := Max(contentBottom + 16, 260)
            maxH := A_ScreenHeight - 40
            myGui.Show("w660 h" Min(winH, maxH) (recenter ? " Center" : ""))
        } finally {
            SetRedraw(true)
            RepaintGui()
        }
    }

    LoadFields() {
        gistTarget.Text := AppState.CloudSyncProvider == "gist"
            ? AppState.CloudSyncTarget
            : ""

        repoOwner.Text := AppState.CloudSyncGitHubOwner
        repoName.Text := AppState.CloudSyncGitHubRepository
        repoBranch.Text := AppState.CloudSyncGitHubBranch
        repoPath.Text := AppState.CloudSyncGitHubPath

        googleClient.Text := AppState.CloudSyncGoogleClientId
        googleTarget.Text := AppState.CloudSyncProvider == "google-drive"
            ? AppState.CloudSyncTarget
            : ""

        oneDriveClient.Text := AppState.CloudSyncOneDriveClientId
        oneDriveTenant.Text := AppState.CloudSyncOneDriveTenant
        oneDrivePath.Text := AppState.CloudSyncOneDrivePath

        webdavUrl.Text := AppState.CloudSyncWebDavUrl
        webdavPath.Text := AppState.CloudSyncWebDavPath
        webdavUser.Text := ""
        webdavPassword.Text := ""

        device.Text := CloudSyncIdentity.GetName()

        labels := Map(
            "gist", "GitHub Gist",
            "github", "GitHub Private Repository",
            "google-drive", "Google Drive",
            "onedrive", "OneDrive",
            "webdav", "WebDAV"
        )
        provider.Text := labels.Has(AppState.CloudSyncProvider)
            ? labels[AppState.CloudSyncProvider]
            : "GitHub Gist"
    }

    SaveSettings(*) {
        previousProviderKey := CloudSyncCoordinator.GetProviderConfigKey()

        switch provider.Text {
            case "GitHub Gist":
                AppState.CloudSyncProvider := "gist"
                AppState.CloudSyncTarget := Trim(gistTarget.Text)

                if gistToken.Text != "" {
                    if !CloudSyncCredentials.Set("gist", "token", gistToken.Text) {
                        ShowToolTip(Lang("MSG_CLOUD_SYNC_CREDENTIAL_SAVE_FAILED", "Could not save the encrypted credential."), 2200)
                        return false
                    }
                    gistToken.Text := ""
                }

            case "GitHub Private Repository":
                AppState.CloudSyncProvider := "github"
                AppState.CloudSyncGitHubOwner := Trim(repoOwner.Text)
                AppState.CloudSyncGitHubRepository := Trim(repoName.Text)
                AppState.CloudSyncGitHubBranch := Trim(repoBranch.Text)
                AppState.CloudSyncGitHubPath := Trim(repoPath.Text)

                if repoToken.Text != "" {
                    if !CloudSyncCredentials.Set("github", "token", repoToken.Text) {
                        ShowToolTip(Lang("MSG_CLOUD_SYNC_CREDENTIAL_SAVE_FAILED", "Could not save the encrypted credential."), 2200)
                        return false
                    }
                    repoToken.Text := ""
                }

            case "Google Drive":
                AppState.CloudSyncProvider := "google-drive"
                AppState.CloudSyncTarget := Trim(googleTarget.Text)
                AppState.CloudSyncGoogleClientId := Trim(googleClient.Text)

            case "OneDrive":
                AppState.CloudSyncProvider := "onedrive"
                AppState.CloudSyncOneDriveClientId := Trim(oneDriveClient.Text)
                AppState.CloudSyncOneDriveTenant := Trim(oneDriveTenant.Text)
                AppState.CloudSyncOneDrivePath := Trim(oneDrivePath.Text)

            case "WebDAV":
                AppState.CloudSyncProvider := "webdav"
                AppState.CloudSyncWebDavUrl := Trim(webdavUrl.Text)
                AppState.CloudSyncWebDavPath := Trim(webdavPath.Text)

                if webdavUser.Text != ""
                    if !CloudSyncCredentials.Set("webdav", "username", webdavUser.Text) {
                        ShowToolTip(Lang("MSG_CLOUD_SYNC_CREDENTIAL_SAVE_FAILED", "Could not save the encrypted credential."), 2200)
                        return false
                    }

                if webdavPassword.Text != ""
                    if !CloudSyncCredentials.Set("webdav", "password", webdavPassword.Text) {
                        ShowToolTip(Lang("MSG_CLOUD_SYNC_CREDENTIAL_SAVE_FAILED", "Could not save the encrypted credential."), 2200)
                        return false
                    }

                webdavUser.Text := ""
                webdavPassword.Text := ""
        }

        AppState.CloudSyncEnabled := enabled.Value == 1
        AppState.CloudSyncAutoEnabled := autoSync.Value == 1
        AppState.CloudSyncDeviceName := Trim(device.Text)

        if IsNumber(interval.Text)
            AppState.CloudSyncInterval := Clamp(Integer(interval.Text), 5, 1440)
        else 
            interval.Text := String(AppState.CloudSyncInterval)

        ConfigManager.Save(false)
        CloudSyncIdentity.Initialize()

        if previousProviderKey != CloudSyncCoordinator.GetProviderConfigKey()
            CloudSyncCoordinator.InvalidateBaseline()

        if AppState.CloudSyncEnabled && AppState.CloudSyncAutoEnabled
            CloudSyncCoordinator.StartAutoSync()
        else
            CloudSyncCoordinator.StopAutoSync()

        return true
    }

    Connect(*) {
        if !SaveSettings()
            return

        if provider.Text == "Google Drive" {
            if GoogleOAuth.Active {
                ShowToolTip(Lang("MSG_CLOUD_SYNC_SYNCING", "Google authorization is already running."), 1800)
                return
            }
        }

        if provider.Text == "OneDrive" {
            if OneDriveOAuth.Active {
                ShowToolTip(Lang("MSG_CLOUD_SYNC_SYNCING", "OneDrive authorization is already running."), 1800)
                return
            }
        }

        if CloudSyncCoordinator.Connect()
            ShowToolTip(Lang("MSG_CLOUD_SYNC_CONNECTED", "Cloud Sync connection validated."), 1800)
        else
            ShowToolTip(Lang("MSG_CLOUD_SYNC_AUTH_FAILED", "Cloud Sync connection failed."), 2200)

        status.Text := CloudSyncCoordinator.GetStatusText()
        ProviderFields()
        lastSuccess.Text := Lang("GUI_CLOUD_SYNC_LAST_SUCCESS", "Last successful synchronization")
            ": " (AppState.CloudSyncLastSuccess != "" ? AppState.CloudSyncLastSuccess : "—")
    }

    Sync(*) {
        if !SaveSettings()
            return

        if CloudSyncCoordinator.SyncNow()
            ShowToolTip(Lang("MSG_CLOUD_SYNC_SUCCESS", "Cloud Sync completed successfully."), 2000)
        else
            ShowToolTip(Lang("MSG_CLOUD_SYNC_FAILED", "Cloud Sync failed or requires attention."), 2400)

        status.Text := CloudSyncCoordinator.GetStatusText()
        ProviderFields()
        lastSuccess.Text := Lang("GUI_CLOUD_SYNC_LAST_SUCCESS", "Last successful synchronization")
            ": " (AppState.CloudSyncLastSuccess != "" ? AppState.CloudSyncLastSuccess : "—")
    }

    Reset(*) {
        answer := MsgBox(
            Lang(
                "CONFIRM_CLOUD_SYNC_RESET",
                "Remove the saved credential, target, and synchronization metadata for the current provider?"
            ),
            Lang("MSG_CONFIRM", "Please confirm"),
            "YesNo Icon?"
        )
        if answer != "Yes"
            return

        CloudSyncCoordinator.ResetProvider()
        LoadFields()
        status.Text := CloudSyncCoordinator.GetStatusText()
        ProviderFields()
        lastSuccess.Text := Lang("GUI_CLOUD_SYNC_LAST_SUCCESS", "Last successful synchronization")
            ": " (AppState.CloudSyncLastSuccess != "" ? AppState.CloudSyncLastSuccess : "—")
    }

    AuthorizeGoogle(*) {
        if !SaveSettings()
            return

        try GoogleOAuth.Authorize()
        catch as err
            ShowToolTip(err.Message, 3000)
    }

    AuthorizeOneDrive(*) {
        if !SaveSettings()
            return

        try OneDriveOAuth.Authorize()
        catch as err
            ShowToolTip(err.Message, 3000)
    }

    provider.OnEvent("Change", (*) => (
        ProviderFields(),
        status.Text := CloudSyncCoordinator.GetStatusText(),
        RepaintGui()
    ))

    googleAuthorize.OnEvent("Click", AuthorizeGoogle)
    oneDriveAuthorize.OnEvent("Click", AuthorizeOneDrive)
    saveBtn.OnEvent("Click", (*) => (
        SaveSettings(),
        status.Text := CloudSyncCoordinator.GetStatusText()
    ))
    connectBtn.OnEvent("Click", Connect)
    syncBtn.OnEvent("Click", Sync)
    resetBtn.OnEvent("Click", Reset)
    disconnectBtn.OnEvent("Click", (*) => (
        CloudSyncCoordinator.Disconnect(),
        status.Text := CloudSyncCoordinator.GetStatusText(),
        lastSuccess.Text := Lang("GUI_CLOUD_SYNC_LAST_SUCCESS", "Last successful synchronization")
            ": " (AppState.CloudSyncLastSuccess != "" ? AppState.CloudSyncLastSuccess : "—")
    ))
    CloseSettings(*) {
        currentGui := ""
        myGui.Destroy()
        return true
    }

    closeBtn.OnEvent("Click", CloseSettings)
    myGui.OnEvent("Escape", CloseSettings)
    myGui.OnEvent("Close", CloseSettings)

    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)

    LoadFields()
    ProviderFields(true)
    provider.Focus()
}
