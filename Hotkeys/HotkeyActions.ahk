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
