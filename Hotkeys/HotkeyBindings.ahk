#Requires AutoHotkey v2.0

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
    return GetKeyState( "CapsLock", "P" ) && !AppState.QuickPhraseTransactionActive
}

QuickPhraseUiActive() {
    if AppState.QuickPhraseTransactionActive
        return true

    return IsObject(AppState.QuickPhraseGui)
        || IsObject(AppState.QuickPhraseVariableGui)
        || IsObject(AppState.QuickPhraseManagerGui)
}


QuickPhraseHotkeyAvailable() {
    return CapsLockHotkeysAvailable()
        && !QuickPhraseUiActive()
}

; True while the switcher's search box owns keyboard focus. Defined here so the
; hotkey variants below resolve it at load time; the switcher GUI itself is only
; touched at runtime.
WindowSwitcherSearchFocused() {
    try {
        if !IsObject(WindowSwitcherGui.Instance)
            return false

        if !WindowSwitcherGui.Instance.HasProp("SearchBox")
            return false

        return DllCall("user32\GetFocus", "Ptr")
            == WindowSwitcherGui.Instance.SearchBox.Hwnd
    } catch
        return false
}

; --- Window switcher (CapsLock + L) keyboard navigation ---
; Scoped to the switcher's search box so arrow keys move the selection while
; typing, without interfering with any other window or GUI.
#HotIf WindowSwitcherSearchFocused()
    Up:: WindowSwitcherGui.MoveSelection( -1 )
    Down:: WindowSwitcherGui.MoveSelection( 1 )
    PgUp:: WindowSwitcherGui.MoveSelection( -5 )
    PgDn:: WindowSwitcherGui.MoveSelection( 5 )
#HotIf

#HotIf GetKeyState( "CapsLock", "P" )
    j:: JumpToLine()
    k:: TerminateProcessByPid()
#HotIf

#HotIf CapsLockHotkeysAvailable()


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

#HotIf CapsLockHotkeysAvailable() && !WindowHole.IsActive()

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

#HotIf CapsLockHotkeysAvailable()

    ; --- Maximize / restore: CapsLock + W / 8 / Num8 ------------------------
    ; CapsLock + Shift + W toggles borderless fullscreen.
    ;
    ; "w" is registered as a wildcard hotkey rather than as a bare "w" plus a
    ; separate "+w": the bare key here heads the stacked "w / 8 / Numpad8"
    ; definition, and a stacked head owns its key, so a later "+w" variant in
    ; the same context is never registered. The wildcard entry point resolves
    ; the modifier state in the handler instead.
    *w:: WindowWildcardMaximize()
    8::
    Numpad8:: ToggleMaximizeActive()

    ; --- Minimize: CapsLock + S / 2 / Num2 ---------------------------------
    ; CapsLock + Shift + S hides the active window to the tray.
    ; Same reasoning as "w" above.
    *s:: WindowWildcardMinimize()
    2::
    Numpad2:: WinMinimize( "A" )

    c:: CopyAsPlainTextAndAddToHistory()

    v:: PasteWithCurrentMode()

    +v:: ShowHistoryMenu()

    f:: ChangeCaseOfLastCopy()

    t:: ToggleAlwaysOnTopWithOSD()

    p:: ConvertWithPandoc()

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
