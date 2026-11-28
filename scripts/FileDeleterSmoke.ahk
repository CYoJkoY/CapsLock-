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

; IsFileBrowserActive() reuses the application-wide text-input list, so the
; smoke test provides the same lookup without pulling in the whole app.
class AppState {
    static TextInputControls := ["Edit", "RichEdit", "RichEdit20W", "Scintilla"]
}

class Theme {
    static Text := "EDEAE2"
    static Control := "25272D"
}

IsTextInputControlClass(controlClass) {
    if controlClass == ""
        return false
    normalized := StrLower(controlClass)
    for knownClass in AppState.TextInputControls
        if normalized == StrLower(knownClass)
            return true
    return false
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

; 5) Focus resolution: the old code compared the ControlGetFocus result (an
;    HWND) against a class name, which never matched. The class helper must
;    recognise text inputs by class name or ClassNN, and must not mistake the
;    shell view for a text input.
if !FileDeleter._IsTextInputClassValue("Edit")
    Fail("Edit should be recognised as a text input")
if !FileDeleter._IsTextInputClassValue("Edit1")
    Fail("the ClassNN Edit1 should be recognised as a text input")
if !FileDeleter._IsTextInputClassValue("RichEdit20W2")
    Fail("the ClassNN RichEdit20W2 should be recognised as a text input")
if FileDeleter._IsTextInputClassValue("DirectUIHWND3")
    Fail("the Explorer shell view must not be treated as a text input")
if FileDeleter._IsTextInputClassValue("SysListView322")
    Fail("SysListView32 must not be mistaken for a text input")
if !FileDeleter._IsTextInputClassValue("InputSiteWindowClass")
    Fail("the Windows 11 address-bar host must be treated as a text input")
if FileDeleter._IsTextInputClassValue("")
    Fail("an empty class must not be treated as a text input")

; 6) Runtime focus resolution: ControlGetFocus returns an HWND in this
;    AutoHotkey build, so the helper has to resolve it to a class name before
;    the text-input test can work.
probeGui := Gui("+AlwaysOnTop", "CapsLock delete focus probe")
probeEdit := probeGui.Add("Edit", "w200", "probe")
probeGui.Show("x-3000 y-3000 w260 h80")
WinWait("ahk_id " probeGui.Hwnd, , 2)
WinActivate("ahk_id " probeGui.Hwnd)
probeEdit.Focus()
Sleep(120)
focusedClass := FileDeleter._FocusedControlClass(probeGui.Hwnd)
if focusedClass != "Edit"
    Fail("focused control class should resolve to Edit, got: " focusedClass)
if !FileDeleter._FocusedControlIsTextInput(probeGui.Hwnd)
    Fail("the focused Edit control should be treated as a text input")
probeGui.Destroy()

FileAppend("PASS: permanent delete, flags, and COM enumeration checks succeeded`n", "*")
ExitApp(0)
