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

    ; --- AI API Settings ---
    items.Push({ label: "🤖 " Lang("MENU_AI_SETTINGS"), callback: (*) => PromptSettingsGui.Show() })

    ; --- Streaming mode toggle ---
    streamLabel := (AppState.ApiStreamMode ? "● " : "○ ") . "⚡ " . Lang("MENU_STREAM_MODE")
    items.Push({ label: streamLabel, callback: (*) => ToggleStreamMode() })
    items.Push({ isSep: true })

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

    ; --- Language (sub-menu) ---
    langChildren := []
    currentLang := Language.GetCurrent()
    for code in Language.GetLanguages() {
        langDisplay := Lang("LANG_" . StrUpper(code), code)
        prefix := (code == currentLang) ? "● " : "○ "
        langChildren.Push({ label: prefix . "🌐 " . langDisplay, callback: SwitchLanguage.Bind(code) })
    }
    items.Push({ label: "🌐 " Lang("MENU_LANGUAGE"), children: langChildren })

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

ToggleStreamMode(*) {
    AppState.ApiStreamMode := !AppState.ApiStreamMode
    ConfigManager.Save()
    ShowToolTip(AppState.ApiStreamMode ? Lang("MSG_STREAM_TOGGLED_ON") : Lang("MSG_STREAM_TOGGLED_OFF"), 2000)
}
