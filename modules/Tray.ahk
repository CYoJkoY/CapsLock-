; =========================== Tray ===========================

TraySetup() {
    global Tray

    A_IconTip := "CapsLock-"

    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("Set ImageMagick Path...", (*) => SetImPath())
    Tray.Add()
    Tray.Add("Open Temp Folder", (*) => Run("explore " A_Temp))

    ModeMenu := Menu()
    ModeMenu.Add("1 - Delete after delay", SetDeleteMode1)
    ModeMenu.Add("2 - Batch cleanup", SetDeleteMode2)
    ModeMenu.Add("3 - Never delete", SetDeleteMode3)
    Tray.Add("Delete Mode", ModeMenu)
    Tray.Add("Mode1: Set Delete Delay...", SetDeleteDelay)
    Tray.Add("Mode2: Set Cleanup Interval...", SetCleanupInterval)
    Tray.Add()
    Tray.Add("Load on start up", ToggleAutoStart)
    Tray.Add("Reload", (*) => Reload())
    Tray.Add("Exit", (*) => ExitApp())

    if IsAutoStartEnabled()
        Tray.Check("Load on start up")
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

TrayMenuRefresh() {
    global DeleteMode, Tray

    try {
        Tray.Check("1 - Delete after delay", DeleteMode = 1)
        Tray.Check("2 - Batch cleanup", DeleteMode = 2)
        Tray.Check("3 - Never delete", DeleteMode = 3)
    }
}

; =========================== Set the ImageMagick path===========================
SetImPath(*) {
    global ImageMagickExe, ConfigFile

    SelectedFile := Trim(FileSelect(1, A_ProgramFiles, "Select ImageMagick's magick.exe", "Executable (*.exe)"))

    if (SelectedFile = "")
        return

    if !FileExist(SelectedFile) {
        MsgBox "Selected file does not exist!", "Error", "Iconx"
        return
    }

    if !InStr(SelectedFile, "magick.exe") {
        MsgBox "Please select the correct file: magick.exe", "Error", "Iconx"
        return
    }

    try {
        IniWrite(SelectedFile, ConfigFile, "ImageMagick", "Path")
    } catch as err {
        MsgBox "Failed to save path: " err.Message, "Error", "Iconx"
        return
    }

    ImageMagickExe := SelectedFile
    MsgBox "ImageMagick path set to: `n" SelectedFile, "Success", "Iconi T2"
}
