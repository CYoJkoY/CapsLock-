#Requires AutoHotkey v2.0

TraySetup() {
    global Tray, ModeMenu, PasteModeMenu, CurrentImMenuText

    A_IconTip := "CapsLock-"

    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add(CurrentImMenuText, (*) => SetImPath())

    Tray.Add()
    Tray.Add("Open Temp Folder", (*) => Run("explore " A_Temp))
    ModeMenu.Delete()
    ModeMenu.Add("1 - Delete after delay", SetDeleteMode1)
    ModeMenu.Add("2 - Batch cleanup", SetDeleteMode2)
    ModeMenu.Add("3 - Never delete", SetDeleteMode3)
    Tray.Add("Delete Mode", ModeMenu)
    Tray.Add("Mode1: Set Delete Delay...", SetDeleteDelay)
    Tray.Add("Mode2: Set Cleanup Interval...", SetCleanupInterval)

    Tray.Add()
    Tray.Add("Set Max History Limit...", SetMaxHistory)
    PasteModeMenu.Delete()
    PasteModeMenu.Add("1 - Paste as File", SetPasteMode1)
    PasteModeMenu.Add("2 - Paste as Text (with source)", SetPasteMode2)
    Tray.Add("Paste Mode", PasteModeMenu)

    Tray.Add()
    Tray.Add("Load on start up", ToggleAutoStart)
    Tray.Add("Reload", (*) => Reload())
    Tray.Add("Exit", (*) => ExitApp())

    RefreshImStatus()
    TrayMenuRefresh()
}

; =========================== ImageMagick Status Refresh ===========================
RefreshImStatus() {
    global ImageMagickExe, CurrentImMenuText, Tray

    isValid := (ImageMagickExe != "")
    && InStr(StrLower(ImageMagickExe), "magick.exe")
    && FileExist(ImageMagickExe)

    newText := isValid ? "ImageMagick: Valid (Click to change)" : "ImageMagick: Not Set / Invalid"

    if (CurrentImMenuText == newText) {
        if (isValid)
            Tray.Check(newText)
        else
            Tray.Uncheck(newText)
        return
    }

    Tray.Insert(CurrentImMenuText, newText, (*) => SetImPath())
    Tray.Delete(CurrentImMenuText)

    if (isValid)
        Tray.Check(newText)
    else
        Tray.Uncheck(newText)

    CurrentImMenuText := newText
}

; =========================== Menu Refresh ===========================
TrayMenuRefresh() {
    global DeleteMode, PasteMode, ModeMenu, PasteModeMenu, Tray

    ModeMenu.Uncheck("1 - Delete after delay")
    ModeMenu.Uncheck("2 - Batch cleanup")
    ModeMenu.Uncheck("3 - Never delete")

    if (DeleteMode = 1)
        ModeMenu.Check("1 - Delete after delay")
    else if (DeleteMode = 2)
        ModeMenu.Check("2 - Batch cleanup")
    else if (DeleteMode = 3)
        ModeMenu.Check("3 - Never delete")

    PasteModeMenu.Uncheck("1 - Paste as File")
    PasteModeMenu.Uncheck("2 - Paste as Text (with source)")

    if (PasteMode = 1)
        PasteModeMenu.Check("1 - Paste as File")
    else if (PasteMode = 2)
        PasteModeMenu.Check("2 - Paste as Text (with source)")

    if IsAutoStartEnabled()
        Tray.Check("Load on start up")
    else
        Tray.Uncheck("Load on start up")
}

; =========================== Auto-start ===========================
ToggleAutoStart(*) {
    global Tray

    RegPath := "Software\Microsoft\Windows\CurrentVersion\Run"
    AppName := "CapsLockExtension"

    if IsAutoStartEnabled() {
        RegDelete("HKEY_CURRENT_USER\" RegPath, AppName)
        Tray.Uncheck("Load on start up")
        MsgBox "Load on start up turn off", "Success", "Iconi T2"
    } else {
        RegWrite('"' A_ScriptFullPath '"', "REG_SZ", "HKEY_CURRENT_USER\" RegPath, AppName)
        Tray.Check("Load on start up")
        MsgBox "Load on start up turn on", "Success", "Iconi T2"
    }
}

IsAutoStartEnabled() {
    try {
        RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "CapsLockExtension")
        return true
    } catch {
        return false
    }
}

; =========================== Switch to paste mode ===========================
SetPasteMode1(*) {
    global PasteMode
    PasteMode := 1
    SaveConfig()
    TrayMenuRefresh()
    ToolTip "Paste Mode: File"
    SetTimer(() => ToolTip(), -2000)
}

SetPasteMode2(*) {
    global PasteMode
    PasteMode := 2
    SaveConfig()
    TrayMenuRefresh()
    ToolTip "Paste Mode: Text"
    SetTimer(() => ToolTip(), -2000)
}

; =========================== Switch to delete mode ===========================
SetDeleteMode1(*) {
    global DeleteMode
    DeleteMode := 1
    SaveConfig()
    TrayMenuRefresh()
    ToolTip "Mode: Delete after delay (" DeleteDelay "s)"
    SetTimer(() => ToolTip(), -2000)
}

SetDeleteMode2(*) {
    global DeleteMode
    DeleteMode := 2
    SaveConfig()
    TrayMenuRefresh()
    ToolTip "Mode: Batch cleanup every " CleanupInterval "s"
    SetTimer(() => ToolTip(), -2000)
}

SetDeleteMode3(*) {
    global DeleteMode
    DeleteMode := 3
    SaveConfig()
    TrayMenuRefresh()
    ToolTip "Mode: Never delete"
    SetTimer(() => ToolTip(), -2000)
}

; =========================== Parameter settings ===========================
SetMaxHistory(*) {
    global MaxHistory
    input := InputBox("Enter max history limit (e.g., 500, 1000, 10000):", "Max History Limit", "w300 h120", MaxHistory
    )

    if (input.Result = "OK" && IsNumber(input.Value) && input.Value > 0) {
        MaxHistory := Integer(input.Value)
        SaveConfig()
        ToolTip "Max history limit set to " MaxHistory
        SetTimer(() => ToolTip(), -2000)
    }
}

SetDeleteDelay(*) {
    global DeleteDelay
    input := InputBox("Enter delete delay in seconds:", "Delete Delay", "w300 h120", DeleteDelay)

    if (input.Result = "OK" && IsNumber(input.Value) && input.Value > 0) {
        DeleteDelay := Integer(input.Value)
        SaveConfig()
        ToolTip "Delete delay set to " DeleteDelay "s"
        SetTimer(() => ToolTip(), -2000)
    }
}

SetCleanupInterval(*) {
    global CleanupInterval, BatchCleanupTimer
    input := InputBox("Enter cleanup interval in seconds:", "Cleanup Interval", "w300 h120", CleanupInterval)

    if (input.Result = "OK" && IsNumber(input.Value) && input.Value > 0) {
        CleanupInterval := Integer(input.Value)
        SaveConfig()

        if (BatchCleanupTimer != "")
            SetTimer(BatchCleanupTimer, CleanupInterval * 1000)

        ToolTip "Cleanup interval set to " CleanupInterval "s"
        SetTimer(() => ToolTip(), -2000)
    }
}

; =========================== Set the ImageMagick path===========================
SetImPath(*) {
    global ImageMagickExe, ConfigFile

    SelectedFile := Trim(FileSelect(1, A_ProgramFiles, "Select ImageMagick's magick.exe", "Executable (*.exe)"))
    if (SelectedFile = "")
        return

    if !InStr(StrLower(SelectedFile), "magick.exe") {
        MsgBox "Please select the correct file: magick.exe", "Error", "Iconx"
        return
    }

    if !FileExist(SelectedFile) {
        MsgBox "Selected file does not exist!`nPath: " SelectedFile, "Error", "Iconx"
        return
    }

    try {
        IniWrite(SelectedFile, ConfigFile, "ImageMagick", "Path")
    } catch as err {
        MsgBox "Failed to save path: " err.Message, "Error", "Iconx"
        return
    }

    ImageMagickExe := SelectedFile

    RefreshImStatus()

    MsgBox "ImageMagick path set successfully!`n" SelectedFile, "Success", "Iconi T2"
}
