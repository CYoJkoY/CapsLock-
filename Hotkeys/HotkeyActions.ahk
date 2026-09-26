#Requires AutoHotkey v2.0

CopyAsPlainTextAndAddToHistory() {
    AppState.IgnoreNextClipChange := true
    text := ClipboardHelper.CopyAsPlainText()
    AppState.IgnoreNextClipChange := false
    if text != ""
        HistoryManager.Add( text, "Plain Text Copy" )
}

ChangeCaseOfLastCopy() {
    source := ( AppState.LastManualClipboard != "" ) ? AppState.LastManualClipboard : A_Clipboard
    if source == "" {
        ToolTip( Lang( "MSG_NO_TEXT" ) )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    if !RegExMatch( source, "[a-zA-Z]", &match ) {
        ToolTip( Lang( "MSG_NO_ENGLISH_LETTERS" ) )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    firstChar := match[ 0 ]
    newText := ( firstChar ~= "[A-Z]" ) ? StrLower( source ) : StrUpper( source )
    prevCaps := GetKeyState( "CapsLock", "T" )
    if prevCaps
        SetCapsLockState( "AlwaysOff" )
    AppState.IgnoreNextClipChange := true
    A_Clipboard := newText
    Send( "^v" )
    Sleep( 200 )
    AppState.IgnoreNextClipChange := true
    A_Clipboard := source
    if prevCaps
        SetCapsLockState( "AlwaysOn" )
}

; --- CapsLock + W / 8 / Num8 and CapsLock + S / 2 / Num2 ------------------
;
; Every key of the two groups reaches these handlers through a wildcard hotkey,
; because a separate "+w" / "+8" / "+s" / "+2" binding next to the stacked
; "w / 8 / Numpad8" and "s / 2 / Numpad2" definitions is never registered: the
; stacked head owns the key and the Shift variant is dropped. Resolving the
; modifier state here keeps one reliable entry point per key.
;
;   CapsLock + W / 8 / Num8             maximize / restore
;   CapsLock + Shift + W / 8 / Num8     borderless fullscreen
;   CapsLock + S / 2 / Num2             minimize
;   CapsLock + Shift + S / 2 / Num2     hide to tray
;
; Ctrl / Alt / Win combinations belong to the active window (Ctrl + S saves,
; Ctrl + W closes a tab), so they are forwarded untouched.

WindowWildcardMaximize() {
    if ForwardModifierKey( WildcardForwardKey( "w" ) )
        return

    if GetKeyState( "Shift", "P" ) {
        WindowFullScreen.Toggle()
        return
    }

    ToggleMaximizeActive()
}

WindowWildcardMinimize() {
    ToolTip(A_ThisHotkey " | shift=" GetKeyState("Shift","P"))
    SetTimer(() => ToolTip(), -2000)

    if ForwardModifierKey( WildcardForwardKey( "s" ) )
        return

    if GetKeyState( "Shift", "P" ) {
        TrayHider.HideActive()
        return
    }

    WinMinimize( "A" )
}

; Bare key name of the wildcard hotkey that is currently running. One handler
; serves "w / 8 / Numpad8" and "s / 2 / Numpad2", so the key that has to be
; re-sent when a Ctrl / Alt / Win combination is forwarded can only come from
; A_ThisHotkey ("*w", "*8", "*Numpad8", ...): the wildcard prefix and any
; modifier symbols are stripped, and fallback keeps the handler usable when it
; is called outside a hotkey (for example from the built-in reference).
WildcardForwardKey( fallback ) {
    name := ""

    try
        name := A_ThisHotkey
    catch {
    }

    name := RegExReplace( name, "^[*$~]+" )
    name := RegExReplace( name, "^[<>]*[\^!+#]*" )

    return name == "" ? fallback : name
}

ToggleMaximizeActive() {
    if WinGetMinMax( "A" ) == 1
        WinRestore( "A" )
    else
        WinMaximize( "A" )
}

; True when Ctrl / Alt / Win is held. The keystroke is not part of the
; CapsLock layer in that case, so it is re-sent to the active window.
;
; The Win key has no neutral name in AutoHotkey v2: GetKeyState() accepts
; "Ctrl", "Alt" and "Shift" as neutral modifiers, but only "LWin" / "RWin" for
; the Windows key. Passing the bare Win name throws "Parameter #1 of
; GetKeyState is invalid", so both physical keys are queried individually.
ForwardModifierKey( key ) {
    if !AnyModifierHeld()
        return false

    Send( "{Blind}{" key "}" )
    return true
}

; Ctrl / Alt / Win state, tolerant of naming differences between AutoHotkey
; builds. Each query is guarded, so an unsupported name degrades to "not held"
; instead of throwing inside a hotkey handler.
AnyModifierHeld() {
    static neutralNames := [ "Ctrl", "Alt", "LWin", "RWin" ]

    for name in neutralNames {
        try {
            if GetKeyState( name, "P" )
                return true
        } catch {
        }
    }

    return false
}

; Open the folder that holds the temporary files created by file workflows.
; The folder is created on demand and an OSD hint reports how many
; temporary files are currently waiting for cleanup.
OpenTempFolder() {
    dir := A_Temp

    if !DirExist(dir) {
        try
            DirCreate(dir)
        catch {
            ShowToolTip(Lang("MSG_TEMP_OPEN_FAIL"), 2500)
            return
        }
    }

    tempCount := 0
    Loop Files, dir "\ClipTemp_*", "F"
        tempCount++

    if !FocusExistingExplorerWindow(dir)
        Run('explore "' dir '"')

    if tempCount == 0
        ShowToolTip(Lang("MSG_TEMP_EMPTY"), 2000)
    else
        ShowToolTip(Lang("MSG_TEMP_OPENED", "", tempCount), 2000)
}

; Activate an already open Explorer window showing dir.
; Returns true when an existing window was focused.
FocusExistingExplorerWindow(dir) {
    SplitPath(dir, &folderName)

    try {
        for hwnd in WinGetList("ahk_class CabinetWClass") {
            try title := WinGetTitle("ahk_id " hwnd)
            catch
                continue

            if title != "" && (InStr(title, folderName) || InStr(title, dir)) {
                WinActivate("ahk_id " hwnd)
                return true
            }
        }
    } catch {
    }

    return false
}

ToggleAlwaysOnTopWithOSD() {
    hwnd := WinExist( "A" )
    WinSetAlwaysOnTop( -1, hwnd )
    isOnTop := WinGetExStyle( hwnd ) & 0x8
    if isOnTop
        SoundHelper.PlayResource( "SND_ON" )
    else
        SoundHelper.PlayResource( "SND_OFF" )
    OSD.ShowTopMostOSD( hwnd, isOnTop )
}


ParsePositiveInteger(text, &value) {
    value := 0
    text := Trim(String(text))

    if !RegExMatch(text, "^\d+$")
        return false

    try
        value := Integer(text)
    catch
        return false

    return value > 0
}

GetProcessIdentity(pid) {
    if !pid
        return ""

    handle := DllCall(
        "OpenProcess",
        "UInt", 0x1000,
        "Int", 0,
        "UInt", pid,
        "Ptr"
    )

    if !handle {
        handle := DllCall(
            "OpenProcess",
            "UInt", 0x0400,
            "Int", 0,
            "UInt", pid,
            "Ptr"
        )
    }

    if !handle
        return ""

    creationTime := Buffer(8, 0)
    exitTime := Buffer(8, 0)
    kernelTime := Buffer(8, 0)
    userTime := Buffer(8, 0)

    ok := DllCall(
        "GetProcessTimes",
        "Ptr", handle,
        "Ptr", creationTime.Ptr,
        "Ptr", exitTime.Ptr,
        "Ptr", kernelTime.Ptr,
        "Ptr", userTime.Ptr,
        "Int"
    )

    identity := ""

    if ok {
        high := NumGet(creationTime, 4, "UInt")
        low := NumGet(creationTime, 0, "UInt")
        identity := Format("{:08X}{:08X}", high, low)
    }

    DllCall("CloseHandle", "Ptr", handle)
    return identity
}

JumpToLine() {
    targetHwnd := WinExist("A")
    if !targetHwnd
        return

    targetControl := 0
    targetControlClass := ""

    try {
        targetControl := ControlGetFocus("ahk_id " targetHwnd)
        if targetControl
            targetControlClass := WinGetClass("ahk_id " targetControl)
    } catch {
        targetControl := 0
        targetControlClass := ""
    }

    result := DarkInputDialog.Show(
        Lang("GUI_GOTO_LINE_PROMPT", "Enter a positive line number:"),
        Lang("GUI_GOTO_LINE_TITLE", "Jump to line")
    )

    if result.Result != "OK"
        return

    lineNumber := 0
    if !ParsePositiveInteger(result.Value, &lineNumber) {
        ShowToolTip(
            Lang("MSG_INVALID_LINE", "Please enter a positive integer line number."),
            1800
        )
        return
    }

    if !WinExist("ahk_id " targetHwnd) {
        ShowToolTip(
            Lang("MSG_TARGET_WINDOW_GONE", "The target window is no longer available."),
            1800
        )
        return
    }

    try {
        WinActivate("ahk_id " targetHwnd)

        if !WinWaitActive("ahk_id " targetHwnd, , 1)
            throw Error("Target window could not be activated.")

        if targetControl
            && WinExist("ahk_id " targetControl)
            && IsTextInputControlClass(targetControlClass)
        {
            try ControlFocus(targetControl, "ahk_id " targetHwnd)
            catch
                targetControl := 0
        }

        Sleep(120)

        SendEvent("^g")
        Sleep(180)

        SendText(String(lineNumber))
        SendEvent("{Enter}")
    } catch {
        ShowToolTip(
            Lang("MSG_TARGET_WINDOW_GONE", "The target window is no longer available."),
            1800
        )
    }
}

IsTextInputControlClass(controlClass) {
    if controlClass == ""
        return false

    normalized := StrLower(controlClass)

    for knownClass in AppState.TextInputControls {
        if normalized == StrLower(knownClass)
            return true
    }

    return false
}

TerminateProcessByPid() {
    result := DarkInputDialog.Show(
        Lang("GUI_KILL_PROCESS_PROMPT", "Enter a positive process ID (PID):"),
        Lang("GUI_KILL_PROCESS_TITLE", "Terminate process")
    )

    if result.Result != "OK"
        return

    pid := 0
    if !ParsePositiveInteger(result.Value, &pid) {
        ShowToolTip(
            Lang("MSG_INVALID_PID", "Please enter a positive integer PID."),
            1800
        )
        return
    }

    if ProcessExist(pid) != pid {
        ShowToolTip(
            Lang("MSG_PROCESS_NOT_FOUND", "The specified process no longer exists."),
            1800
        )
        return
    }

    processName := ""
    try
        processName := ProcessGetName(pid)
    catch
        processName := Lang("MSG_UNKNOWN_PROCESS", "Unknown process")

    if processName == ""
        processName := Lang("MSG_UNKNOWN_PROCESS", "Unknown process")

    originalIdentity := GetProcessIdentity(pid)

    if originalIdentity == "" {
        ShowToolTip(
            Lang(
                "MSG_PROCESS_QUERY_FAILED",
                "The process could not be queried. It may be protected or access is denied."
            ),
            2500
        )
        return
    }

    answer := MsgBox(
        Lang(
            "CONFIRM_KILL_PROCESS",
            "Force-terminate this process?\nPID: {1}\nProcess: {2}\nUnsaved data may be lost.",
            pid,
            processName
        ),
        Lang("GUI_KILL_PROCESS_TITLE", "Terminate process"),
        "YesNo Icon!"
    )

    if answer != "Yes"
        return

    if ProcessExist(pid) != pid {
        ShowToolTip(
            Lang("MSG_PROCESS_NOT_FOUND", "The specified process no longer exists."),
            1800
        )
        return
    }

    currentIdentity := GetProcessIdentity(pid)

    if currentIdentity == "" || currentIdentity != originalIdentity {
        ShowToolTip(
            Lang(
                "MSG_PROCESS_CHANGED",
                "The process changed before termination. No action was taken."
            ),
            2200
        )
        return
    }

    closeSucceeded := false

    try
        closeSucceeded := ProcessClose(pid) == pid
    catch {
        closeSucceeded := false
    }

    if !closeSucceeded {
        fallbackIdentity := GetProcessIdentity(pid)
        if fallbackIdentity == "" || fallbackIdentity != originalIdentity {
            ShowToolTip(
                Lang(
                    "MSG_PROCESS_CHANGED",
                    "The process changed before termination. No action was taken."
                ),
                2200
            )
            return
        }

        try
            RunWait("taskkill.exe /F /PID " pid, , "Hide")
        catch {
        }
    }

    if ProcessWaitClose(pid, 2) != 0 {
        fallbackIdentity := GetProcessIdentity(pid)

        if fallbackIdentity == "" || fallbackIdentity != originalIdentity {
            ShowToolTip(
                Lang(
                    "MSG_PROCESS_CHANGED",
                    "The process changed before termination. No action was taken."
                ),
                2200
            )
            return
        }

        try
            RunWait("taskkill.exe /F /PID " pid, , "Hide")
        catch {
        }

        if ProcessWaitClose(pid, 2) != 0 {
            ShowToolTip(
                Lang(
                    "MSG_PROCESS_CLOSE_FAILED",
                    "The process could not be terminated. It may be protected or access is denied."
                ),
                2500
            )
            return
        }
    }

    ShowToolTip(
        Lang(
            "MSG_PROCESS_TERMINATED",
            "Process {1} ({2}) was terminated.",
            pid,
            processName
        ),
        2000
    )
}
