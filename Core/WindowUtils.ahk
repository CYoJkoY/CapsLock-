#Requires AutoHotkey v2.0

AdjustOpacity( step ) {
    hwnd := WinExist( "A" )
    if !hwnd
        return
    current := WinGetTransparent( hwnd )
    if current == ""
        current := 255
    newVal := Clamp( current + step, 20, 255 )
    WinSetTransparent( newVal, hwnd )
}

; --- Shared guards for the window-level hotkeys (Shift + W / Shift + S) ----
; These helpers are used by both borderless fullscreen and hide-to-tray so the
; two features reject exactly the same set of windows.

; True while hwnd still identifies a live window. IsWindow() is used instead of
; WinExist() because hidden windows are invisible to WinExist() with the
; default DetectHiddenWindows setting.
WindowHandleAlive( hwnd ) {
    if !hwnd
        return false
    try
        return DllCall( "user32\IsWindow", "Ptr", hwnd, "Int" ) != 0
    catch
        return false
}

; True for windows owned by CapsLock- itself (cheatsheet, history, dialogs).
; The script must never restyle or hide its own UI through its own hotkeys.
WindowIsOwnProcess( hwnd ) {
    if !hwnd
        return false
    if hwnd == A_ScriptHwnd
        return true
    try
        return WinGetPID( "ahk_id " hwnd ) == ProcessExist()
    catch
        return false
}

; True when hwnd can safely be restyled or hidden. The shell surfaces (desktop,
; taskbar) and windows that belong to CapsLock- are excluded.
WindowIsManageable( hwnd ) {
    if !WindowHandleAlive( hwnd )
        return false

    if WindowIsOwnProcess( hwnd )
        return false

    try {
        if !WinExist( "ahk_id " hwnd )
            return false

        className := WinGetClass( "ahk_id " hwnd )

        for blockedClass in [ "Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd" ] {
            if className == blockedClass
                return false
        }

        return true
    } catch
        return false
}

; Window title that never fails; used for tray labels and OSD hints.
WindowSafeTitle( hwnd ) {
    title := ""
    try
        title := WinGetTitle( "ahk_id " hwnd )
    catch
        title := ""

    if title == ""
        title := Lang( "MSG_UNTITLED_WINDOW", "Untitled window" )

    return title
}

; Process name that never fails; used for tray labels.
WindowSafeProcessName( hwnd ) {
    name := ""
    try
        name := WinGetProcessName( "ahk_id " hwnd )
    catch
        name := ""

    return name
}

; Process id that never fails; 0 for protected or already closed windows.
WindowSafePid( hwnd ) {
    pid := 0
    try
        pid := WinGetPID( "ahk_id " hwnd )
    catch
        pid := 0

    return pid
}
