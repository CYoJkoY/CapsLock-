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
