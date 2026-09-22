#Requires AutoHotkey v2.0

; AppState is provided by the root script's Config\\Globals.ahk include.
IsSet(AppState)

*CapsLock:: {
    if !( A_PriorKey = "CapsLock" )
        return
    if ( A_TimeSincePriorHotkey > 300 || A_TimeSincePriorHotkey < 50 )
        return
    if GetKeyState( "CapsLock", "T" )
        SetCapsLockState( "AlwaysOff" )
    else
        SetCapsLockState( "AlwaysOn" )
}

CapsLockHotkeysAvailable() {
    return GetKeyState( "CapsLock", "P" )
}

QuickPhraseUiActive() {
    if AppState.QuickPhraseTransactionActive
        return true

    return IsObject(AppState.QuickPhraseGui)
        || IsObject(AppState.QuickPhraseVariableGui)
        || IsObject(AppState.QuickPhraseManagerGui)
}

CapsLockActionHotkeysAvailable() {
    return CapsLockHotkeysAvailable() && !QuickPhraseUiActive()
}

QuickPhraseHotkeyAvailable() {
    return CapsLockHotkeysAvailable()
        && !QuickPhraseUiActive()
        && !AppState.QuickPhraseClipboardRestorePending
}

#HotIf

#HotIf CapsLockActionHotkeysAvailable()


    +Left:: Send( "^+{Left}" )
    +Right:: Send( "^+{Right}" )
    +Up:: Send( "+{Home}" )
    +Down:: Send( "+{End}" )

    Space:: Send( "^{Left}^+{Right}" )

    ~a:: Send( "{Backspace}" )
    ~d:: Send( "{Delete}" )
    ~+a:: Send( "^{Backspace}" )
    ~+d:: Send( "^{Delete}" )
    ~Backspace:: Send( "{Home}+{End}{Delete}" )
    ~Delete:: Send( "{Home}+{End}{Delete}" )

    q:: Send( "^{PgUp}" )
    e:: Send( "^{PgDn}" )

#HotIf CapsLockActionHotkeysAvailable() && !WindowHole.IsActive()

    LButton:: {
        AdjustOpacity( 20 )
        if KeyWait( "LButton", "T0.3" )
            return
        while GetKeyState( "LButton", "P" ) {
            AdjustOpacity( 5 )
            Sleep( 50 )
        }
    }

    RButton:: {
        AdjustOpacity( -20 )
        if KeyWait( "RButton", "T0.3" )
            return
        while GetKeyState( "RButton", "P" ) {
            AdjustOpacity( -5 )
            Sleep( 50 )
        }
    }

    MButton:: {
        hwnd := WinExist( "A" )
        current := WinGetTransparent( hwnd )
        if current == "" || current == 255
            WinSetTransparent( 10, hwnd )
        else
            WinSetTransparent( 255, hwnd )
    }

#HotIf CapsLockActionHotkeysAvailable()

    w::
    8::
    Numpad8:: {
        if WinGetMinMax( "A" ) == 1
            WinRestore( "A" )
        else
            WinMaximize( "A" )
    }

    s::
    2::
    Numpad2:: WinMinimize( "A" )

    c:: CopyAsPlainTextAndAddToHistory()

    v:: PasteWithCurrentMode()

    +v:: ShowHistoryMenu()

    f:: ChangeCaseOfLastCopy()

    t:: ToggleAlwaysOnTopWithOSD()

    p:: ConvertWithPandoc()

    j:: JumpToLine()
    k:: TerminateProcessByPid()
    l:: WindowSwitcherGui.Show()

    x:: WindowHole.HandleXDown()

    ; --- Files: open the temp folder used by file-oriented paste ---
    !q:: OpenTempFolder()

    ; --- Help: built-in hotkey reference ---
    h::
    F1:: HotkeyReferenceGui.Toggle()

#HotIf

; X-up is intentionally global so releasing X still stops hold mode even
; when CapsLock is released first. The tilde keeps the key-up event visible.
~x up:: WindowHole.HandleXUp()

#HotIf QuickPhraseHotkeyAvailable() && AppState.QuickPhraseEnabled
    +p:: QuickPhraseHandleHotkey()
#HotIf


; Window Hole second-level penetration is registered as a global hotkey and
; enabled only for the lifetime of an active Window Hole session. This avoids
; #HotIf timing on the CapsLock + X + 1 sequence.
WindowHole.InitializeSecondLevelHotkey()
