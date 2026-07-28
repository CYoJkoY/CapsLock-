#Requires AutoHotkey v2.0

PasteFile(filePath, fileType := "auto") {
    if fileType == "auto"
        fileType := GetFileType(filePath)

    if fileType == "pdf" || fileType == "image" {
        ClipboardHelper.SetClipboardFile(filePath)
    } else {
        sourceInfo := "Copied from: File | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        content := ""

        try content := FileRead(filePath, "UTF-8")
        catch
            content := "[File content could not be read]"

        full := "; " sourceInfo "`n`n" content
        tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
        FileAppend(full, tempFile, "UTF-8")

        ClipboardHelper.SetClipboardFile(tempFile)
        CleanupManager.ScheduleDeletion(tempFile)
        filePath := tempFile
    }

    ActivateAndPaste()

    if fileType == "pdf" && InStr(filePath, A_Temp "\ClipTemp_")
        CleanupManager.ScheduleDeletion(filePath)

    ShowToolTip(Lang("MSG_PASTE_FILE_TYPE", "", fileType), 1500)
}

ActivateAndPaste() {
    targetHwnd := AppState.TargetWindow
    activeHwnd := WinExist("A")

    if targetHwnd && WinExist("ahk_id " targetHwnd) {
        if activeHwnd != targetHwnd
            WinActivate("ahk_id " targetHwnd)
    } else if activeHwnd {
        WinActivate("ahk_id " activeHwnd)
    }

    Sleep(100)
    Send("^v")
}

GetFileType(filePath) {
    SplitPath(filePath, , , &ext)
    ext := StrLower(ext)

    if ext == "pdf"
        return "pdf"

    for fmt in AppState.TextFormats
        if ext == fmt
            return "text"

    for fmt in AppState.ImageFormats
        if ext == fmt
            return "image"

    return "unknown"
}
