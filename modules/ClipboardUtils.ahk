#Requires AutoHotkey v2.0

FormatBytes(bytes) {
    if (bytes < 1024)
        return bytes " B"
    else if (bytes < 1048576)
        return Round(bytes / 1024, 1) " KB"
    else if (bytes < 1073741824)
        return Round(bytes / 1048576, 1) " MB"
    else if (bytes < 1099511627776)
        return Round(bytes / 1073741824, 1) " GB"

    return Round(bytes / 1099511627776, 1) " TB"
}

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

IsMultiFilePathText(text) {
    if !(text is String) || (text = "")
        return false

    local lines := StrSplit(text, "`n", "`r")
    if (lines.Length < 1)
        return false

    local valid_file_count := 0
    for line in lines {
        line := Trim(line)
        if (line = "")
            continue

        local attrs := FileExist(line)
        if (attrs != "" && !InStr(attrs, "D")) {
            valid_file_count++
        } else {
            return false
        }
    }
    return (valid_file_count >= 1)
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

CopyAsPlainText() {
    bak := ClipboardAll()
    A_Clipboard := ""
    Send "^c"

    if !ClipWait(1) {
        A_Clipboard := bak
        return ""
    }

    text := A_Clipboard

    if (text == "") {
        A_Clipboard := bak
        return ""
    }

    if (InStr(text, "`n") && FileExist(StrSplit(text, "`n", "`r")[1])) {
        A_Clipboard := bak
        return ""
    }

    A_Clipboard := text
    return text
}

ReadMultipleFilesAsText(file_paths) {
    local result := ""
    local timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    for idx, file_path in file_paths {
        file_path := Trim(file_path)
        if (file_path = "")
            continue

        local file_name := ""
        SplitPath(file_path, &file_name)
        local file_size := FileGetSize(file_path)
        local size_str := FormatBytes(file_size)

        result .= "; =========================================================================`n"
        result .= "; FILE: " file_path "`n"
        result .= "; NAME: " file_name " | SIZE: " size_str " | TIME: " timestamp "`n"
        result .= "; =========================================================================`n"

        try {
            ; Attempt UTF-8 read; fallback handled by catch
            local content := FileRead(file_path, "UTF-8")
            result .= content "`n`n"
        } catch as err {
            result .= "[ERROR: Failed to read file - " err.Message "]`n`n"
        }
    }

    return RTrim(result, "`n")
}
