#Requires AutoHotkey v2.0

CopyAsPlainTextAndAddToHistory() {
    global ignoreNextClipChange
    ignoreNextClipChange := true
    text := CopyAsPlainText()
    ignoreNextClipChange := false
    if ( text != "" ) {
        AddToHistory( text, "Plain Text Copy" )
    }
}

ChangeCaseOfLastCopy() {
    global lastManualClipboard, ignoreNextClipChange

    sourceText := ( lastManualClipboard != "" ) ? lastManualClipboard : A_Clipboard
    if ( sourceText = "" ) {
        ToolTip( "No text to paste. Please copy something first." )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    if !RegExMatch( sourceText, "[a-zA-Z]", &match ) {
        ToolTip( "No English letters found" )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    firstChar := match[ 0 ]
    newText := ( firstChar ~= "[A-Z]" ) ? StrLower( sourceText ) : StrUpper( sourceText )

    prevCapsState := GetKeyState( "CapsLock", "T" )
    if prevCapsState {
        SetCapsLockState( "AlwaysOff" )
    }

    ignoreNextClipChange := true
    A_Clipboard := newText
    Send( "^v" )
    Sleep( 200 )

    ignoreNextClipChange := true
    A_Clipboard := sourceText

    if prevCapsState {
        SetCapsLockState( "AlwaysOn" )
    }
}

ToggleAlwaysOnTopWithOSD() {
    hwnd := WinExist( "A" )
    WinSetAlwaysOnTop( -1, hwnd )
    isOnTop := WinGetExStyle( hwnd ) & 0x8
    if isOnTop {
        PlayResourceSound( "SND_ON" )
    } else {
        PlayResourceSound( "SND_OFF" )
    }
    ShowTopMostOSD( hwnd, isOnTop )
}
