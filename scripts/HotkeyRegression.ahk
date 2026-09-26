#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Regression checks for the window-level hotkeys.
;
;   CapsLock + Shift + W  -  borderless fullscreen   (Core\WindowFullScreen.ahk)
;   CapsLock + Shift + S  -  hide to tray            (Core\TrayHider.ahk)
;
; The checks are intentionally static: they only read source files and the
; language resource, so the script needs no interactive Windows session and
; never touches a real window.
;
; Run from the repository root:
;     AutoHotkey64.exe /ErrorStdOut scripts\HotkeyRegression.ahk
;
; Exit code 0 = every check passed, 1 = at least one check failed.
; ---------------------------------------------------------------------------

Failures := 0

root := A_ScriptDir "\.."

bindings := ReadFile( root "\Hotkeys\HotkeyBindings.ahk" )
actions := ReadFile( root "\Hotkeys\HotkeyActions.ahk" )
reference := ReadFile( root "\Hotkeys\HotkeyReference.ahk" )
trayMenu := ReadFile( root "\Tray\TrayMenu.ahk" )
main := ReadFile( root "\CapsLock-.ahk" )
csv := ReadFile( root "\lang.csv" )

; --- New modules are wired into the script -------------------------------

Check( FileExist( root "\Core\WindowFullScreen.ahk" ), "Core\WindowFullScreen.ahk exists" )
Check( FileExist( root "\Core\TrayHider.ahk" ), "Core\TrayHider.ahk exists" )
Check( InStr( main, "Core\WindowFullScreen.ahk" ) != 0, "main script includes WindowFullScreen" )
Check( InStr( main, "Core\TrayHider.ahk" ) != 0, "main script includes TrayHider" )
Check( InStr( main, "RestoreManagedWindows" ) != 0, "exit handler restores managed windows" )

; --- The two new bindings -------------------------------------------------
;
; W and S must be wildcard hotkeys. A bare "w"/"s" heading a stacked
; definition owns its key, so a separate "+w"/"+s" variant in the same #HotIf
; context is never registered and the Shift action silently does nothing.
; These checks lock that failure mode down.

Check(
    InStr( bindings, "*w:: WindowWildcardMaximize()" ) != 0,
    "CapsLock + W is a wildcard hotkey routed through WindowWildcardMaximize()"
)
Check(
    InStr( bindings, "*s:: WindowWildcardMinimize()" ) != 0,
    "CapsLock + S is a wildcard hotkey routed through WindowWildcardMinimize()"
)
Check(
    InStr( bindings, "+w::" ) == 0 && InStr( bindings, "+s::" ) == 0,
    "no separate +w / +s variant can be shadowed by a stacked head"
)
Check(
    InStr( actions, "WindowWildcardMinimize()" ) != 0
    && InStr( actions, "TrayHider.HideActive()" ) != 0,
    "Shift + S reaches TrayHider.HideActive()"
)
Check(
    InStr( actions, "WindowWildcardMaximize()" ) != 0
    && InStr( actions, "WindowFullScreen.Toggle()" ) != 0,
    "Shift + W reaches WindowFullScreen.Toggle()"
)
Check(
    InStr( actions, "ForwardModifierKey(" ) != 0
    && InStr( actions, "AnyModifierHeld(" ) != 0,
    "Ctrl / Alt / Win combinations are forwarded to the active window"
)

; GetKeyState() has no neutral Win name in AutoHotkey v2 — passing it throws
; "Parameter #1 of GetKeyState is invalid", which surfaces as a broken hotkey.
; Only Ctrl, Alt, Shift and the explicit LWin / RWin names are valid.
;
; Each GetKeyState literal is validated against that allow-list so an invalid
; key name can never reach a running build again.
invalidKeyNames := ""
scanPos := 1

while RegExMatch( actions, "O)GetKeyState\(\s*`"([A-Za-z]+)`"\s*,", &km, scanPos ) {
    scanPos := km.Pos + km.Len

    if !ValueInList( km[ 1 ], [ "Ctrl", "Alt", "Shift", "LWin", "RWin", "CapsLock", "LButton", "RButton", "MButton" ] )
        invalidKeyNames .= ( invalidKeyNames == "" ? "" : ", " ) . km[ 1 ]
}

Check( invalidKeyNames == "", "GetKeyState key names are valid (" invalidKeyNames ")" )

; A bare quoted Win token anywhere in the handler file is the same bug: it can
; only ever be a key name, and there is no such key.
quote := Chr( 34 )

Check(
    !InStr( actions, quote "Win" quote ),
    "no bare Win key name is used anywhere in the hotkey actions"
)

; --- Existing CapsLock + W / CapsLock + S behaviour is untouched ----------

Check(
    InStr( bindings, "Numpad8:: ToggleMaximizeActive()" ) != 0,
    "CapsLock + W / 8 / Num8 still maximizes and restores"
)
Check(
    InStr( bindings, "Numpad2:: WinMinimize" ) != 0,
    "CapsLock + S / 2 / Num2 still minimizes"
)
Check(
    InStr( actions, "ToggleMaximizeActive()" ) != 0,
    "maximize / restore logic moved into a reusable handler"
)

; --- Built-in reference ---------------------------------------------------

Check(
    InStr( reference, "CapsLock + Shift + W" ) != 0
    && InStr( reference, "CHEAT_ACT_BORDERLESS" ) != 0,
    "hotkey reference lists borderless fullscreen"
)
Check(
    InStr( reference, "CapsLock + Shift + S" ) != 0
    && InStr( reference, "CHEAT_ACT_HIDE_TRAY" ) != 0,
    "hotkey reference lists hide-to-tray"
)

; --- Tray menu offers a way back ------------------------------------------

Check(
    InStr( trayMenu, "TrayHider.MenuItems()" ) != 0,
    "tray menu restores hidden windows"
)
Check(
    InStr( trayMenu, "RestoreManagedWindows()" ) != 0
    && InStr( trayMenu, "ReloadWithRestore" ) != 0
    && InStr( trayMenu, "ExitWithRestore" ) != 0,
    "reload and exit restore managed windows"
)

; --- Localization ---------------------------------------------------------

langKeys := Map()
langRows := Map()

for line in StrSplit( csv, "`n" ) {
    line := Trim( line, " `t`r" )

    if line == ""
        continue

    parts := StrSplit( line, "," )

    if parts.Length < 14
        continue

    key := parts[ 1 ]

    if SubStr( key, 1, 3 ) == "key"
        continue

    langKeys[ key ] := true
    langRows[ key ] := parts
}

requiredKeys := [
    "CHEAT_ACT_BORDERLESS",
    "CHEAT_ACT_HIDE_TRAY",
    "MSG_BORDERLESS_ON",
    "MSG_BORDERLESS_OFF",
    "MSG_BORDERLESS_UNSUPPORTED",
    "MSG_TRAY_HIDDEN",
    "MSG_TRAY_RESTORED",
    "MSG_TRAY_HIDE_UNSUPPORTED",
    "MSG_TRAY_WINDOW_GONE",
    "MENU_HIDDEN_WINDOWS",
    "MENU_HIDDEN_NONE",
    "MENU_HIDDEN_RESTORE_ALL",
    "MSG_UNTITLED_WINDOW"
]

for key in requiredKeys {
    Check( langKeys.Has( key ), "lang.csv defines " key )

    if !langKeys.Has( key )
        continue

    row := langRows[ key ]
    translated := 0

    loop 13 {
        if Trim( row[ A_Index + 1 ] ) != ""
            translated++
    }

    Check( translated == 13, key " is translated into all 13 languages" )
}

; Every reference row must resolve to a language key, otherwise the overlay
; shows a raw key instead of a description.
missingDesc := ""

pos := 1

while RegExMatch( reference, "O)(CHEAT_(?:ACT|CAT)_[A-Z0-9_]+)", &match, pos ) {
    key := match[ 1 ]
    pos := match.Pos + match.Len

    if !langKeys.Has( key )
        missingDesc .= ( missingDesc == "" ? "" : ", " ) . key
}

Check( missingDesc == "", "every reference key exists in lang.csv (" missingDesc ")" )

; --- Result ---------------------------------------------------------------

if Failures == 0 {
    FileAppend( "`nAll hotkey regression checks passed.`n", "*" )
    ExitApp( 0 )
}

FileAppend( "`n" Failures " check(s) failed.`n", "*" )
ExitApp( 1 )

; --- Helpers --------------------------------------------------------------

ReadFile( path ) {
    if !FileExist( path )
        return ""

    return FileRead( path, "UTF-8" )
}

Check( ok, label ) {
    global Failures

    if ok {
        FileAppend( "PASS  " label "`n", "*" )
        return
    }

    FileAppend( "FAIL  " label "`n", "*" )
    Failures += 1
}

ValueInList( value, list ) {
    for entry in list {
        if entry == value
            return true
    }

    return false
}
