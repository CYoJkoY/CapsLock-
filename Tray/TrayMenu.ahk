#Requires AutoHotkey v2.0

TrayMsgHandler(wParam, lParam, msg, hwnd) {
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

BuildTrayMenuItems() {
    items := []

    ; --- ImageMagick status ---
    exe := AppState.ImageMagickExe
    valid := exe != "" && InStr(StrLower(exe), "magick.exe") && FileExist(exe)
    imLabel := valid
        ? "📦 " Lang("MENU_IM_STATUS_SET")
        : "📦 " Lang("MENU_IM_STATUS_NOTSET")
    items.Push({ label: imLabel, callback: (*) => SetImPath() })

    ; --- Pandoc settings (sub-menu) ---
    pandocChildren := []
    pandocChildren.Push({ label: "📁 " Lang("MENU_PANDOC_PATH"), callback: (*) => SetPandocPath() })
    pandocChildren.Push({ label: "📤 " Lang("MENU_PANDOC_OUTPUT", , AppState.PandocOutputFormat), callback: (*) => SetPandocOutput() })

    pandocValid := AppState.PandocExe != "" && FileExist(AppState.PandocExe)
    pandocLabel := pandocValid
        ? "📄 " Lang("MENU_PANDOC_STATUS_SET")
        : "📄 " Lang("MENU_PANDOC_STATUS_NOTSET")
    items.Push({ label: pandocLabel, children: pandocChildren })

    items.Push({ isSep: true })

    ; --- Open temp folder ---
    items.Push({ label: "📂 " Lang("MENU_OPEN_TEMP"), callback: (*) => Run("explore " A_Temp) })

    items.Push({ isSep: true })

    ; --- Cleanup settings (sub-menu) ---
    cleanupChildren := []
    dm := AppState.DeleteMode
    cleanupChildren.Push({ label: (dm == 1 ? "● " : "○ ") . Lang("MENU_MODE1"), callback: (*) => SetDeleteMode(1) })
    cleanupChildren.Push({ label: (dm == 2 ? "● " : "○ ") . Lang("MENU_MODE2"), callback: (*) => SetDeleteMode(2) })
    cleanupChildren.Push({ label: (dm == 3 ? "● " : "○ ") . Lang("MENU_MODE3"), callback: (*) => SetDeleteMode(3) })
    cleanupChildren.Push({ label: "⏱️ " Lang("MENU_SET_DELAY"),   callback: (*) => SetDeleteDelay() })
    cleanupChildren.Push({ label: "🔄 " Lang("MENU_SET_INTERVAL"), callback: (*) => SetCleanupInterval() })
    items.Push({ label: "🧹 " Lang("MENU_CLEANUP_SETTINGS"), children: cleanupChildren })

    ; --- History & Paste settings (sub-menu) ---
    historyChildren := []
    historyChildren.Push({ label: "📝 " Lang("MENU_MAX_HISTORY"), callback: (*) => SetMaxHistory() })
    pm := AppState.PasteMode
    historyChildren.Push({ label: (pm == 1 ? "● " : "○ ") . Lang("MENU_PASTE_FILE"), callback: (*) => SetPasteMode(1) })
    historyChildren.Push({ label: (pm == 2 ? "● " : "○ ") . Lang("MENU_PASTE_TEXT"), callback: (*) => SetPasteMode(2) })
    historyChildren.Push({ label: "🚫 " Lang("MENU_IGNORE_RULES"), callback: (*) => SetIgnorePatterns() })
    items.Push({ label: "📋 " Lang("MENU_HISTORY_PASTE"), children: historyChildren })

    ; --- Quick Phrases (sub-menu) ---
    quickPhraseChildren := []
    quickPhrasePrefix := AppState.QuickPhraseEnabled ? "● " : "○ "
    quickPhraseChildren.Push({
        label: quickPhrasePrefix . Lang("MENU_QUICK_PHRASE_ENABLE", "Enable shortcut"),
        callback: (*) => ToggleQuickPhraseEnabled()
    })
    quickPhraseChildren.Push({
        label: "📝 " Lang("MENU_QUICK_PHRASE_MANAGE", "Manage phrases..."),
        callback: (*) => ShowQuickPhraseManager()
    })
    items.Push({
        label: "💬 " Lang("MENU_QUICK_PHRASE", "Quick Phrases"),
        children: quickPhraseChildren
    })

    ; --- Cloud Sync settings (sub-menu) ---
    cloudSyncChildren := []
    cloudSyncChildren.Push({
        label: (AppState.CloudSyncEnabled ? "● " : "○ ")
            . Lang("MENU_CLOUD_SYNC_ENABLE", "Enable synchronization"),
        callback: (*) => ToggleCloudSync()
    })
    cloudSyncChildren.Push({
        label: "⚙️ " Lang("MENU_CLOUD_SYNC_SETTINGS", "Cloud Sync Settings..."),
        callback: (*) => ShowCloudSyncSettings()
    })
    cloudSyncChildren.Push({
        label: "☁ " Lang("MENU_CLOUD_SYNC_NOW", "Sync now"),
        callback: (*) => CloudSyncCoordinator.SyncNow()
    })
    cloudSyncChildren.Push({
        label: "🔌 " Lang("MENU_CLOUD_SYNC_DISCONNECT", "Disconnect"),
        callback: (*) => CloudSyncCoordinator.Disconnect()
    })
    items.Push({
        label: "☁ " Lang("MENU_CLOUD_SYNC", "Cloud Sync"),
        children: cloudSyncChildren
    })

    ; --- Window Hole settings (sub-menu) ---
    windowHoleChildren := []
    windowHoleChildren.Push({
        label: "📏 " Lang("MENU_WINDOW_HOLE_SIZE", "Hole size"),
        callback: (*) => SetWindowHoleDiameter()
    })

    shapeChildren := []
    shapeChildren.Push({
        label: (AppState.WindowHoleShape == "circle" ? "● " : "○ ") . Lang("MENU_WINDOW_HOLE_SHAPE_CIRCLE", "Circle"),
        callback: (*) => SetWindowHoleShape("circle")
    })
    shapeChildren.Push({
        label: (AppState.WindowHoleShape == "rounded" ? "● " : "○ ") . Lang("MENU_WINDOW_HOLE_SHAPE_ROUNDED", "Rounded rectangle"),
        callback: (*) => SetWindowHoleShape("rounded")
    })
    shapeChildren.Push({
        label: (AppState.WindowHoleShape == "square" ? "● " : "○ ") . Lang("MENU_WINDOW_HOLE_SHAPE_SQUARE", "Square"),
        callback: (*) => SetWindowHoleShape("square")
    })
    windowHoleChildren.Push({
        label: "◇ " Lang("MENU_WINDOW_HOLE_SHAPE", "Hole shape"),
        children: shapeChildren
    })

    activationChildren := []
    activationChildren.Push({
        label: (AppState.WindowHoleActivation == "hold" ? "● " : "○ ") . Lang("MENU_WINDOW_HOLE_HOLD", "Hold X"),
        callback: (*) => SetWindowHoleActivation("hold")
    })
    activationChildren.Push({
        label: (AppState.WindowHoleActivation == "toggle" ? "● " : "○ ") . Lang("MENU_WINDOW_HOLE_TOGGLE", "Toggle with X"),
        callback: (*) => SetWindowHoleActivation("toggle")
    })
    windowHoleChildren.Push({
        label: "⌨️ " Lang("MENU_WINDOW_HOLE_ACTIVATION", "Activation"),
        children: activationChildren
    })

    fallbackPrefix := AppState.WindowHoleFallbackToMinimize ? "● " : "○ "
    windowHoleChildren.Push({
        label: fallbackPrefix . Lang("MENU_WINDOW_HOLE_FALLBACK", "Minimize incompatible windows"),
        callback: (*) => ToggleWindowHoleFallback()
    })

    windowHoleChildren.Push({
        label: "⚙️ " Lang("MENU_WINDOW_HOLE_RULES", "Window rules"),
        callback: (*) => SetWindowHoleRules()
    })

    items.Push({
        label: "◉ " Lang("MENU_WINDOW_HOLE", "Window Hole"),
        children: windowHoleChildren
    })

    ; --- Language (sub-menu) ---
    langChildren := []
    currentLang := Language.GetCurrent()
    for code in Language.GetLanguages() {
        langDisplay := Lang("LANG_" . StrUpper(code), code)
        prefix := (code == currentLang) ? "● " : "○ "
        langChildren.Push({ label: prefix . "🌐 " . langDisplay, callback: SwitchLanguage.Bind(code) })
    }
    items.Push({ label: "🌐 " Lang("MENU_LANGUAGE"), children: langChildren })

    ; --- Hotkey reference (same overlay as CapsLock + H / F1) ---
    items.Push({ label: "⌨️ " Lang("MENU_CHEATSHEET"), callback: (*) => OpenCheatsheetFromTray() })

    items.Push({ isSep: true })

    ; --- Auto-start ---
    autoStartEnabled := IsAutoStartEnabled()
    items.Push({ label: (autoStartEnabled ? "✓ " : "") . "🚀 " . Lang("MENU_AUTOSTART"), callback: (*) => ToggleAutoStart() })

    ; --- Rebuild language cache ---
    items.Push({ label: "🔧 " Lang("MENU_REBUILD_LANG"), callback: (*) => RebuildLangCache() })

    items.Push({ isSep: true })

    ; --- Reload / Exit ---
    items.Push({ label: "🔄 " Lang("MENU_RELOAD"), callback: (*) => Reload() })
    items.Push({ label: "❌ " Lang("MENU_EXIT"),   callback: (*) => ExitApp() })

    return items
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
