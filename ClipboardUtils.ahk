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
