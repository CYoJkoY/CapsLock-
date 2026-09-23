#Requires AutoHotkey v2.0

; These symbols are provided by the root script's includes.
IsSet(AppState)
IsSet(DarkInputDialog)

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

        Sleep(80)

        Send("^g")
        Sleep(80)

        SendText(String(lineNumber))
        Send("{Enter}")
    } catch {
        ShowToolTip(
            Lang("MSG_TARGET_WINDOW_GONE", "The target window is no longer available."),
            1800
        )
    }
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

    try
        closedPid := ProcessClose(pid)
    catch {
        ShowToolTip(
            Lang(
                "MSG_PROCESS_CLOSE_FAILED",
                "The process could not be terminated. It may be protected or access is denied."
            ),
            2500
        )
        return
    }

    if closedPid != pid {
        ShowToolTip(
            Lang(
                "MSG_PROCESS_CLOSE_FAILED",
                "The process could not be terminated. It may be protected or access is denied."
            ),
            2500
        )
        return
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
