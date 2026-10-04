#Requires AutoHotkey v2.0

TrayMsgHandler(wParam, lParam, msg, hwnd) {
    if (lParam == 0x203) {
        ; Double-click on tray icon opens the dedicated Settings GUI directly.
        ShowSettingsGui()
        return
    }
    if (lParam == 0x205) {
        msgPos := DllCall("GetMessagePos", "UInt")
        x := msgPos & 0xFFFF
        y := (msgPos >> 16) & 0xFFFF
        if (x & 0x8000)
            x := x | 0xFFFF0000
        if (y & 0x8000)
            y := y | 0xFFFF0000
        ShowTrayCustomMenu(x, y)
    }
}

TraySetup() {
    global AppState
    A_IconTip := "CapsLock-"
    A_TrayMenu.Delete()
    OnMessage(0x404, TrayMsgHandler)
}

ShowTrayCustomMenu(x, y) {
    items := BuildTrayMenuItems()
    if items.Length == 0
        return
    CustomMenu.ShowWithItems(x, y, items, true)
}

; Streamlined Tray Menu:
; All detailed configuration now lives in the dedicated Google-style
; Settings Center (SettingsGui), while the tray menu surfaces the primary
; Settings entry and high-frequency quick actions.
BuildTrayMenuItems() {
    items := []

    ; --- Primary entry: Dedicated Settings Center ---
    items.Push({
        label: Lang("MENU_SETTINGS"),
        callback: (*) => ShowSettingsGui()
    })

    items.Push({ isSep: true })

    ; --- High-frequency quick actions ---
    items.Push({
        label: Lang("GUI_FULL_TITLE"),
        callback: (*) => ShowFullHistoryGui()
    })

    items.Push({
        label: "¶ " . Lang("MENU_QUICK_PHRASE_MANAGE"),
        callback: (*) => ShowQuickPhraseManager()
    })

    items.Push({
        label: Lang("MENU_CLOUD_SYNC_NOW"),
        callback: (*) => (AppState.CloudSyncEnabled ? CloudSyncCoordinator.SyncNow() : ShowCloudSyncSettings())
    })

    items.Push({
        label: Lang("MENU_CHEATSHEET"),
        callback: (*) => OpenCheatsheetFromTray()
    })

    items.Push({ isSep: true })

    ; --- Always-on-top pinned windows (quick unpin / badge toggle) ---
    topmostChildren := []
    indicatorPrefix := AppState.AlwaysOnTopIndicator ? "● " : "○ "
    topmostChildren.Push({
        label: indicatorPrefix . Lang("MENU_TOPMOST_INDICATOR"),
        callback: (*) => ToggleAlwaysOnTopIndicator()
    })

    pinned := PinIndicator.PinnedWindows()
    if pinned.Length > 0 {
        topmostChildren.Push({ isSep: true })
        for hwnd in pinned {
            topmostChildren.Push({
                label: "✦ " . PinIndicator.MenuLabel(hwnd),
                callback: PinIndicator.MakeUnpinCallback(hwnd)
            })
        }
    } else {
        topmostChildren.Push({ isSep: true })
        topmostChildren.Push({
            label: "· " . Lang("MENU_TOPMOST_NONE")
        })
    }

    items.Push({
        label: "✦ " . Lang("MENU_TOPMOST") . " (" . pinned.Length . ")",
        children: topmostChildren
    })

    ; --- Hidden windows restore (CapsLock + Shift + S) ---
    hiddenLabel := "— " . Lang("MENU_HIDDEN_WINDOWS") . " (" . TrayHider.Count() . ")"
    items.Push({ label: hiddenLabel, children: TrayHider.MenuItems() })

    ; --- Quick Theme Switch (sub-menu) ---
    themeChildren := []
    for mode in Theme.Modes {
        themeChildren.Push({
            label: (mode == Theme.Current ? "● " : "○ ") . Theme.Label(mode),
            callback: SetTheme.Bind(mode)
        })
    }
    items.Push({
        label: Lang("MENU_THEME") . ": " . Theme.Label(Theme.Current),
        children: themeChildren
    })

    items.Push({ isSep: true })

    ; --- Open temp folder ---
    items.Push({ label: Lang("MENU_OPEN_TEMP"), callback: (*) => Run("explore " A_Temp) })

    ; --- Reload / Exit ---
    items.Push({ label: "↻ " . Lang("MENU_RELOAD"), callback: (*) => ReloadWithRestore() })
    items.Push({ label: "× " . Lang("MENU_EXIT"),   callback: (*) => ExitWithRestore() })

    return items
}

; Undo every window-level change made by CapsLock + Shift + W / Shift + S.
RestoreManagedWindows() {
    WindowFullScreen.RestoreAll( true )
    TrayHider.RestoreAll( true )
}

ReloadWithRestore(*) {
    RestoreManagedWindows()
    Reload()
}

ExitWithRestore(*) {
    RestoreManagedWindows()
    ExitApp()
}

RefreshImStatus() {
}

TrayMenuRefresh() {
}

RebuildLangCache(*) {
    global AppState
    csvPath := A_ScriptDir "\lang.csv"

    if !FileExist(csvPath) {
        MsgBox(Lang("MSG_LANG_CSV_NOT_FOUND", "", csvPath), Lang("MSG_ERROR"), "Iconx")
        return
    }

    cacheDir := A_ScriptDir "\langs"
    if DirExist(cacheDir) {
        Loop Files, cacheDir "\*.lang", "F" {
            try FileDelete(A_LoopFileFullPath)
        }
    }

    if LanguagePack.BuildAllFromCSV(csvPath) {
        LanguagePack.Init()
        LanguagePack.Load(Language.GetCurrent())
        count := Language.GetLanguages().Length
        MsgBox(
            Lang("MSG_LANG_REBUILT", "", count),
            Lang("MSG_SUCCESS"), "Iconi T2"
        )
    } else {
        MsgBox(Lang("MSG_LANG_REBUILD_FAIL"), Lang("MSG_ERROR"), "Iconx")
    }
}

ToggleAutoStart(*) {
    global AppState
    RegPath := "Software\Microsoft\Windows\CurrentVersion\Run"
    AppName := "CapsLock-"
    if IsAutoStartEnabled() {
        RegDelete("HKEY_CURRENT_USER\" RegPath, AppName)
        MsgBox(Lang("MSG_AUTOSTART_OFF"), Lang("MSG_SUCCESS"), "Iconi T2")
    } else {
        RegWrite('"' A_ScriptFullPath '"', "REG_SZ", "HKEY_CURRENT_USER\" RegPath, AppName)
        MsgBox(Lang("MSG_AUTOSTART_ON"), Lang("MSG_SUCCESS"), "Iconi T2")
    }
}

IsAutoStartEnabled() {
    try {
        RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "CapsLock-")
        return true
    } catch {
        return false
    }
}

SwitchLanguage(code, *) {
    if Language.SetLanguage(code) {
        A_IconTip := "CapsLock-"
        if IsObject(AppState.FullHistoryGui) {
            try AppState.FullHistoryGui.Destroy()
            AppState.FullHistoryGui := ""
        }
        ToolTip(Lang("MSG_LANG_CHANGED", , code))
        SetTimer(() => ToolTip(), -1500)
    }
}

; Tray entry point for the built-in hotkey reference.
; A menu click reads as "open": reuse an already-open overlay instead of
; toggling it closed (Toggle() would close it and look like nothing happened).
OpenCheatsheetFromTray(*) {
    if IsObject(HotkeyReferenceGui.gui) {
        try {
            if WinExist("ahk_id " HotkeyReferenceGui.gui.Hwnd) {
                WinActivate("ahk_id " HotkeyReferenceGui.gui.Hwnd)
                return
            }
        } catch {
        }

        HotkeyReferenceGui.Close()
    }
    HotkeyReferenceGui.Show()
}


ToggleCloudSync(*) {
    AppState.CloudSyncEnabled := !AppState.CloudSyncEnabled

    if !AppState.CloudSyncEnabled {
        AppState.CloudSyncAutoEnabled := false
        CloudSyncCoordinator.StopAutoSync()
        CloudSyncState.Set("Sync", "state", "disabled")
    } else {
        CloudSyncState.Set("Sync", "state", "idle")
        if AppState.CloudSyncAutoEnabled
            CloudSyncCoordinator.StartAutoSync()
    }

    ConfigManager.Save()
    ShowToolTip(
        AppState.CloudSyncEnabled
            ? Lang("MSG_CLOUD_SYNC_ENABLED", "Cloud Sync enabled.")
            : Lang("MSG_CLOUD_SYNC_DISABLED", "Cloud Sync disabled."),
        1800
    )
}
