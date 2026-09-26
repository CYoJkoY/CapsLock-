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

Check(
    InStr( bindings, "+w:: WindowFullScreen.Toggle()" ) != 0,
    "CapsLock + Shift + W is bound to WindowFullScreen.Toggle()"
)
Check(
    InStr( bindings, "+s:: TrayHider.HideActive()" ) != 0,
    "CapsLock + Shift + S is bound to TrayHider.HideActive()"
)

; --- Existing CapsLock + W / CapsLock + S behaviour is untouched ----------

Check(
    InStr( bindings, "Numpad8::" ) != 0 && InStr( bindings, "WinMaximize" ) != 0,
    "CapsLock + W / 8 / Num8 still maximizes and restores"
)
Check(
    InStr( bindings, "Numpad2:: WinMinimize" ) != 0,
    "CapsLock + S / 2 / Num2 still minimizes"
)
Check(
    InStr( bindings, "+w:: WinMaximize" ) == 0 && InStr( bindings, "+s:: WinMinimize" ) == 0,
    "no Shift variant overwrote the plain W / S actions"
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
