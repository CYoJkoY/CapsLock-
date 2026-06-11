#Requires AutoHotkey v2.0

*CapsLock:: {
    if !( A_PriorKey = "CapsLock" ) {
        return
    }
    if ( A_TimeSincePriorHotkey > 300 || A_TimeSincePriorHotkey < 50 ) {
        return
    }
    if GetKeyState( "CapsLock", "T" ) {
        SetCapsLockState( "AlwaysOff" )
    } else {
        SetCapsLockState( "AlwaysOn" )
    }
}

#HotIf GetKeyState( "CapsLock", "P" )

    Left:: Send( "^{Left}" )
    Right:: Send( "^{Right}" )
    Up:: Send( "{Home}" )
    Down:: Send( "{End}" )

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

    e:: Send( "^{PgDn}" )
    q:: Send( "^{PgUp}" )

    LButton:: {
        AdjustOpacity( 20 )
        if KeyWait( "LButton", "T0.3" ) {
            return
        }
        while GetKeyState( "LButton", "P" ) {
            AdjustOpacity( 5 )
            Sleep( 50 )
        }
    }

    RButton:: {
        AdjustOpacity( -20 )
        if KeyWait( "RButton", "T0.3" ) {
            return
        }
        while GetKeyState( "RButton", "P" ) {
            AdjustOpacity( -5 )
            Sleep( 50 )
        }
    }

    MButton:: {
        hwnd := WinExist( "A" )
        currentTrans := WinGetTransparent( hwnd )
        if ( currentTrans = "" || currentTrans = 255 ) {
            WinSetTransparent( 10, hwnd )
        } else {
            WinSetTransparent( 255, hwnd )
        }
    }

    w::
    8::
    Numpad8:: {
        if WinGetMinMax( "A" ) = 1 {
            WinRestore( "A" )
        } else {
            WinMaximize( "A" )
        }
    }

    s::
    2::
    Numpad2:: WinMinimize( "A" )

    c:: CopyAsPlainTextAndAddToHistory()

    v:: PasteWithCurrentMode()

    +v:: ShowHistoryMenu()

    f:: ChangeCaseOfLastCopy()

    t:: ToggleAlwaysOnTopWithOSD()

#HotIf
