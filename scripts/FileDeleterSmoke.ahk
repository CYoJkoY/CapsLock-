#Requires AutoHotkey v2.0
#SingleInstance Force

; Exercise the parts of permanent deletion that a syntax check cannot cover:
; enumerating a shell collection the way GetSelectedFiles does, the actual
; IFileOperation delete path, and the flags that keep items out of the
; Recycle Bin. Only files this script creates are ever deleted.
Lang(key, default := "", params*) {
    return default != "" ? default : key
}

ShowToolTip(*) {
}

class ThemeHelper {
    static StyleGui(*) {
    }

    static AddTitle(gui, text, width := 0) {
        return gui.Add("Text", "", text)
    }

    static AddButton(gui, options, text, style := "") {
        return gui.Add("Button", options, text)
    }

    static ApplyWindowTheme(*) {
    }

    static MarkSurface(*) {
    }
}

#Include "..\Core\FileDeleter.ahk"

Fail(message) {
    FileAppend("FAIL: " message "`n", "*")
    ExitApp(1)
}

; 1) ComObject collections are enumerated directly by GetSelectedFiles.
shell := ComObject("Shell.Application")
folder := shell.NameSpace("C:\")
enumerated := 0
firstPath := ""
for item in folder.Items() {
    if !item.IsFileSystem
        continue
    firstPath := item.Path
    enumerated++
    break
}
if enumerated != 1 || firstPath == ""
    Fail("COM FolderItems enumeration (for item in Items()) did not yield a filesystem item")
if !InStr(firstPath, ":\")
    Fail("enumerated item did not expose an absolute Path: " firstPath)

; 2) Deletion must not offer undo, and must run without UI prompts.
flags := FileDeleter.OperationFlags
if (flags & 0x40)
    Fail("OperationFlags contains FOF_ALLOWUNDO, so items would go to the Recycle Bin")
for required in [0x4, 0x10, 0x400]
    if !(flags & required)
        Fail("OperationFlags is missing a silent/no-confirm/no-error flag: " Format("{:#x}", required))

; 3) Real permanent delete of files created by this script.
tempDir := A_Temp "\CapsLockDeleteSmoke_" A_TickCount
DirCreate(tempDir)
paths := []
Loop 2 {
    path := tempDir "\victim" A_Index ".txt"
    FileAppend("smoke", path)
    paths.Push(path)
}

result := FileDeleter.DeletePaths(paths)
for path in paths
    if FileExist(path)
        Fail("IFileOperation left a file behind: " path)
if !result
    Fail("DeletePaths reported failure after a successful deletion (GetAnyOperationsAborted slot)")

try DirDelete(tempDir)

; 4) Invalid input is reported instead of silently succeeding.
relative := FileDeleter.DeletePaths(["relative\path.txt"])
if relative
    Fail("DeletePaths accepted a relative path")

FileAppend("PASS: permanent delete, flags, and COM enumeration checks succeeded`n", "*")
ExitApp(0)
