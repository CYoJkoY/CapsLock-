#Requires AutoHotkey v2.0

SetClipboardFile(filePath) {
    static DROPFILES_SIZE := 20
    pathLen := StrLen(filePath)
    buf := Buffer(DROPFILES_SIZE + (pathLen + 2) * 2, 0)

    NumPut("UInt", DROPFILES_SIZE, buf, 0)
    NumPut("UInt", 1, buf, 16)
    StrPut(filePath, buf.Ptr + DROPFILES_SIZE, "UTF-16")

    if (!DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)) {
        return
    }

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
    totalBytes := CalculateDropFilesSize(fileArray, DROPFILES_SIZE)
    buf := Buffer(totalBytes, 0)

    WriteDropFilesHeader(buf, DROPFILES_SIZE)
    WriteDropFilesPaths(buf, fileArray, DROPFILES_SIZE)
    PushBufferToClipboard(buf)
}

ClearClipboard() {
    if (DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)) {
        DllCall("EmptyClipboard")
        DllCall("CloseClipboard")
    }
}

CopyAsPlainText() {
    bak := ClipboardAll()
    A_Clipboard := ""
    Send "^c"

    if (!ClipWait(1)) {
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

CalculateDropFilesSize(fileArray, headerSize) {
    totalBytes := headerSize
    for path in fileArray {
        totalBytes += StrPut(path, "UTF-16") * 2
    }
    return totalBytes + 2
}

WriteDropFilesHeader(buf, headerSize) {
    NumPut("UInt", headerSize, buf, 0)
    NumPut("UInt", 0, buf, 4)
    NumPut("UInt", 0, buf, 8)
    NumPut("UInt", 0, buf, 12)
    NumPut("UInt", 1, buf, 16)
}

WriteDropFilesPaths(buf, fileArray, headerSize) {
    offset := headerSize
    for path in fileArray {
        StrPut(path, buf.Ptr + offset, "UTF-16")
        offset += StrPut(path, "UTF-16") * 2
    }
}

PushBufferToClipboard(buf) {
    if (!DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)) {
        return
    }
    DllCall("EmptyClipboard")
    hMem := DllCall("GlobalAlloc", "UInt", 0x42, "Ptr", buf.Size, "Ptr")
    pMem := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", pMem, "Ptr", buf.Ptr, "Ptr", buf.Size)
    DllCall("GlobalUnlock", "Ptr", hMem)
    DllCall("SetClipboardData", "UInt", 0xF, "Ptr", hMem)
    DllCall("CloseClipboard")
}
