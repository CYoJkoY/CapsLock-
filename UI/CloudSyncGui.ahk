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
        560
    )
    ThemeHelper.AddSubtitle(
        myGui,
        Lang(
            "GUI_CLOUD_SYNC_SUBTITLE",
            "Optional synchronization for CapsLock- settings and Quick Phrases."
        ),
        560
    )
    ThemeHelper.AddSeparator(myGui, 560)

    enabled := myGui.Add(
        "CheckBox",
        "w560 y+12 c" AppState.THEME_FG,
        Lang("GUI_CLOUD_SYNC_ENABLE", "Enable Cloud Sync")
    )
    enabled.Value := AppState.CloudSyncEnabled ? 1 : 0

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.AddText(
        "w560 y+14",
        Lang("GUI_CLOUD_SYNC_PROVIDER", "Provider")
    )
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

    provider := myGui.Add(
        "ComboBox",
        "w560 y+6 Choose1 " ThemeHelper.GetEditOptions(),
        ["GitHub Gist"]
    )
    provider.Choose(1)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.AddText(
        "w560 y+12",
        Lang("GUI_CLOUD_SYNC_TARGET", "Target Gist ID (leave blank to create one automatically)")
    )
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

    target := myGui.Add(
        "Edit",
        "w560 r1 y+6 " ThemeHelper.GetEditOptions(),
        AppState.CloudSyncTarget
    )
    ThemeHelper.StyleEdit(target)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.AddText(
        "w560 y+12",
        Lang("GUI_CLOUD_SYNC_GITHUB_TOKEN", "GitHub token")
    )
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

    token := myGui.Add(
        "Edit",
        "Password w560 r1 y+6 " ThemeHelper.GetEditOptions(),
        ""
    )
    ThemeHelper.StyleEdit(token)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.AddText(
        "w560 y+6",
        Lang(
            "GUI_CLOUD_SYNC_TOKEN_HINT",
            "Leave blank to keep the existing encrypted token. Tokens are stored locally with Windows DPAPI."
        )
    )

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.AddText(
        "w560 y+12",
        Lang("GUI_CLOUD_SYNC_DEVICE_NAME", "Device name")
    )
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

    device := myGui.Add(
        "Edit",
        "w560 r1 y+6 " ThemeHelper.GetEditOptions(),
        CloudSyncIdentity.GetName()
    )
    ThemeHelper.StyleEdit(device)

    autoSync := myGui.Add(
        "CheckBox",
        "w300 y+14 c" AppState.THEME_FG,
        Lang("GUI_CLOUD_SYNC_AUTO", "Enable automatic synchronization")
    )
    autoSync.Value := AppState.CloudSyncAutoEnabled ? 1 : 0

    interval := myGui.Add(
        "Edit",
        "w90 r1 x+10 yp " ThemeHelper.GetEditOptions(),
        String(AppState.CloudSyncInterval)
    )
    ThemeHelper.StyleEdit(interval)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.AddText(
        "x+8 yp+3",
        Lang("GUI_CLOUD_SYNC_MINUTES", "minutes")
    )
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

    status := myGui.Add(
        "Text",
        "w560 y+14 c" AppState.THEME_FG_DIM,
        CloudSyncCoordinator.GetStatusText()
    )

    saveBtn := ThemeHelper.AddButton(
        myGui,
        "Default w110 y+16",
        "✓ " Lang("GUI_SAVE", "Save"),
        "primary"
    )
    connectBtn := ThemeHelper.AddButton(
        myGui,
        "x+8 w110",
        Lang("GUI_CLOUD_SYNC_CONNECT", "Connect")
    )
    syncBtn := ThemeHelper.AddButton(
        myGui,
        "x+8 w110",
        "☁ " Lang("GUI_CLOUD_SYNC_SYNC_NOW", "Sync now")
    )
    resetBtn := ThemeHelper.AddButton(
        myGui,
        "x+8 w110",
        Lang("GUI_CLOUD_SYNC_RESET", "Reset"),
        "danger"
    )
    closeBtn := ThemeHelper.AddButton(
        myGui,
        "x+8 w90",
        Lang("GUI_FULL_CLOSE", "Close")
    )

    RefreshStatus(*) {
        status.Text := CloudSyncCoordinator.GetStatusText()
    }

    SaveSettings(*) {
        AppState.CloudSyncEnabled := enabled.Value == 1
        AppState.CloudSyncProvider := "gist"
        AppState.CloudSyncTarget := Trim(target.Text)
        AppState.CloudSyncAutoEnabled := autoSync.Value == 1
        AppState.CloudSyncDeviceName := Trim(device.Text)

        if IsNumber(interval.Text) {
            AppState.CloudSyncInterval := Clamp(Integer(interval.Text), 5, 1440)
            interval.Text := String(AppState.CloudSyncInterval)
        }

        if token.Text != "" {
            if !CloudSyncCredentials.Set("gist", "token", token.Text) {
                ShowToolTip(
                    Lang("MSG_CLOUD_SYNC_CREDENTIAL_SAVE_FAILED", "Could not save the encrypted credential."),
                    2200
                )
                return
            }
            token.Text := ""
        }

        ConfigManager.Save()
        CloudSyncIdentity.Initialize()

        if AppState.CloudSyncEnabled && AppState.CloudSyncAutoEnabled
            CloudSyncCoordinator.StartAutoSync()
        else
            CloudSyncCoordinator.StopAutoSync()

        RefreshStatus()
        ShowToolTip(
            Lang("MSG_CLOUD_SYNC_SETTINGS_SAVED", "Cloud Sync settings saved."),
            1600
        )
    }

    Connect(*) {
        SaveSettings()
        if CloudSyncCoordinator.Connect()
            ShowToolTip(
                Lang("MSG_CLOUD_SYNC_CONNECTED", "Cloud Sync connection validated."),
                1800
            )
        else
            ShowToolTip(
                Lang("MSG_CLOUD_SYNC_AUTH_FAILED", "Cloud Sync connection failed."),
                2200
            )
        RefreshStatus()
    }

    Sync(*) {
        SaveSettings()
        if CloudSyncCoordinator.SyncNow()
            ShowToolTip(
                Lang("MSG_CLOUD_SYNC_SUCCESS", "Cloud Sync completed successfully."),
                2000
            )
        else
            ShowToolTip(
                Lang("MSG_CLOUD_SYNC_FAILED", "Cloud Sync failed or requires attention."),
                2400
            )
        RefreshStatus()
    }

    Reset(*) {
        answer := MsgBox(
            Lang(
                "CONFIRM_CLOUD_SYNC_RESET",
                "Remove the saved provider credential, target, and sync metadata?"
            ),
            Lang("MSG_CONFIRM", "Please confirm"),
            "YesNo Icon?"
        )
        if answer != "Yes"
            return

        CloudSyncCoordinator.ResetProvider()
        target.Text := ""
        token.Text := ""
        RefreshStatus()
    }

    saveBtn.OnEvent("Click", SaveSettings)
    connectBtn.OnEvent("Click", Connect)
    syncBtn.OnEvent("Click", Sync)
    resetBtn.OnEvent("Click", Reset)
    closeBtn.OnEvent("Click", (*) => myGui.Destroy())
    myGui.OnEvent("Escape", (*) => myGui.Destroy())
    myGui.OnEvent("Close", (*) => myGui.Destroy())

    myGui.OnEvent("Close", (*) => currentGui := "")
    myGui.OnEvent("Destroy", (*) => currentGui := "")

    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
    myGui.Show("w600 h620 AutoSize Center")
}
