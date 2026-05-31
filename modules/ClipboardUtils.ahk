; =========================== ClipboardUtils ===========================
; Clipboard manipulation utilities
; Requires: Constants.ahk

SetClipboardFile(filePath) {
    static DROPFILES_SIZE := 20

    pathLen := StrLen(filePath)
    buf := Buffer(DROPFILES_SIZE + (pathLen + 2) * 2, 0)
    NumPut("UInt", DROPFILES_SIZE, buf, 0)
    NumPut("UInt", 1, buf, 16)
    StrPut(filePath, buf.Ptr + DROPFILES_SIZE, "UTF-16")

    if !DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)
        return

    DllCall("EmptyClipboard")
    hMem := DllCall("GlobalAlloc", "UInt", 0x42, "Ptr", buf.Size, "Ptr")
    pMem := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", pMem, "Ptr", buf.Ptr, "Ptr", buf.Size)
    DllCall("GlobalUnlock", "Ptr", hMem)
    DllCall("SetClipboardData", "UInt", 0xF, "Ptr", hMem)
    DllCall("CloseClipboard")
}

SetClipboardFiles(fileArray) {
    static DROPFILES_SIZE := 20

    totalBytes := DROPFILES_SIZE

    for path in fileArray
        totalBytes += StrPut(path, "UTF-16") * 2

    totalBytes += 2

    buf := Buffer(totalBytes, 0)

    NumPut("UInt", DROPFILES_SIZE, buf, 0)
    NumPut("UInt", 0, buf, 4)
    NumPut("UInt", 0, buf, 8)
    NumPut("UInt", 0, buf, 12)
    NumPut("UInt", 1, buf, 16)

    offset := DROPFILES_SIZE

    for path in fileArray {
        StrPut(path, buf.Ptr + offset, "UTF-16")
        offset += StrPut(path, "UTF-16") * 2
    }

    if !DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)
        return

    DllCall("EmptyClipboard")
    hMem := DllCall("GlobalAlloc", "UInt", 0x42, "Ptr", buf.Size, "Ptr")
    pMem := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", pMem, "Ptr", buf.Ptr, "Ptr", buf.Size)
    DllCall("GlobalUnlock", "Ptr", hMem)
    DllCall("SetClipboardData", "UInt", 0xF, "Ptr", hMem)
    DllCall("CloseClipboard")
}

ClearClipboard() {
    if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
        DllCall("EmptyClipboard")
        DllCall("CloseClipboard")
    }
}

Clamp(val, min, max) => (val < min) ? min : (val > max) ? max : val

AdjustOpacity(step) {
    hwnd := WinExist("A")
    currentTrans := WinGetTransparent(hwnd)

    if (currentTrans = "")
        currentTrans := 255

    newTrans := Clamp(currentTrans + step, 20, 255)
    WinSetTransparent(newTrans, hwnd)
}

IsFilePath(text) {
    if (InStr(text, ":\") || InStr(text, "\\")) {
        ext := SubStr(text, InStr(text, ".", , -1) + 1)

        if (ext != "" && StrLen(ext) < 12) {
            return true
        }
    }

    return false
}

GetFileType(filePath) {
    global ImageFormats

    ext := SubStr(filePath, InStr(filePath, ".", , -1) + 1)
    ext := StrLower(ext)

    if (ext = "pdf")
        return "pdf"

    if (ext = "txt" || ext = "ini" || ext = "ahk" || ext = "js" || ext = "py" || ext = "cpp" || ext = "h")
        return "text"

    for format in ImageFormats {
        if (ext = format)
            return "image"
    }

    return "unknown"
}

PasteFile(filePath, fileType := "auto") {
    global LastManualClipboard, TargetWindow

    if (fileType = "auto")
        fileType := GetFileType(filePath)

    if (fileType = "pdf" || fileType = "image") {
        ClearClipboard()
        SetClipboardFile(filePath)
    } else {
        sourceInfo := "Copied from: " (fileType = "pdf" ? "PDF file" : "File") " | Time: " FormatTime(,
            "yyyy-MM-dd HH:mm:ss")

        try
            content := FileRead(filePath, "UTF-8")
        catch
            content := "[File content could not be read]"

        fullContent := "; " sourceInfo "`n`n" content
        tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
        FileAppend fullContent, tempFile, "UTF-8"

        ClearClipboard()
        SetClipboardFile(tempFile)

        ScheduleFileDeletion(tempFile)
        SetTimer () => (
            (LastManualClipboard != "") ? (A_Clipboard := LastManualClipboard) : ""
        ), -10000
    }

    if TargetWindow && WinExist("ahk_id " TargetWindow)
        WinActivate("ahk_id " TargetWindow)
    else
        WinActivate("A")

    Sleep 100
    Send "^v"

    if (fileType = "pdf" && InStr(filePath, A_Temp "\ClipTemp_")) {
        ScheduleFileDeletion(filePath)
        SetTimer () => (
            (LastManualClipboard != "") ? (A_Clipboard := LastManualClipboard) : ""
        ), -10000
    } else if (LastManualClipboard != "") {
        SetTimer () => (A_Clipboard := LastManualClipboard), -10000
    }

    ToolTip "Pasted " fileType " file"
    SetTimer () => ToolTip(), -1500
}

ProcessImagePathsToPDF() {
    global ImageMagickExe

    if (ImageMagickExe = "") {
        MsgBox "Please set ImageMagick path first via tray icon menu.", "Error", "Iconx 4096"
        return ""
    }

    if !FileExist(ImageMagickExe) {
        MsgBox "ImageMagick executable not found at: `n" ImageMagickExe "`nPlease set the correct path.", "Error",
            "Iconx 4096"
        return ""
    }

    imgPaths := StrSplit(A_Clipboard, "`n", "`r")
    validPaths := []

    for idx, line in imgPaths {
        line := Trim(line)

        if (line = "")
            continue

        if FileExist(line)
            validPaths.Push('"' line '"')
    }

    if (validPaths.Length = 0) {
        ToolTip "No valid image files found in clipboard."
        SetTimer () => ToolTip(), -2000
        return ""
    }

    OutputPDF := A_Temp "\ClipTemp_" A_TickCount ".pdf"

    command := '"' ImageMagickExe '" '

    for path in validPaths
        command .= path " "

    command .= '-density 150 -quality 100 "' OutputPDF '"'

    ToolTip "Merging " validPaths.Length " images to PDF..."

    try {
        RunWait(command, , "Hide")

        if (FileExist(OutputPDF)) {
            ToolTip "PDF created successfully!"
            SetTimer () => ToolTip(), -2000
            return OutputPDF
        } else {
            ToolTip "Failed to create PDF"
            SetTimer () => ToolTip(), -2000
            return ""
        }
    } catch as err {
        ToolTip "Failed to create PDF: " err.Message
        SetTimer () => ToolTip(), -3000
        return ""
    }
}

IsImagePathsText(text) {
    global ImageFormats

    if !(text is String)
        return false

    if text = ""
        return false

    if InStr(text, A_Temp "\ClipTemp_")
        return false

    lines := StrSplit(text, "`n", "`r")

    if lines.Length < 2
        return false

    for idx, line in lines {
        line := Trim(line)

        if (line = "")
            continue

        if !FileExist(line)
            return false

        ext := SubStr(line, InStr(line, ".", , -1) + 1)
        ext := StrLower(ext)

        isImage := false

        for format in ImageFormats {
            if (ext = format) {
                isImage := true
                break
            }
        }

        if !isImage
            return false
    }

    return true
}
