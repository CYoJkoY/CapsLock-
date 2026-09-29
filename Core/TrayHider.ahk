#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Hide-to-tray for the active window (CapsLock + Shift + S / 2).
;
; The active window is hidden with WinHide(), which removes it from the desktop
; and from the taskbar while the application keeps running. Hidden windows are
; listed in a "Hidden windows" entry of the CapsLock- tray menu, where a single
; click restores one window and "Restore all" brings every hidden window back.
;
; Hidden windows are tracked by handle. A watcher drops entries whose window
; was closed while hidden, and every window is restored when the script exits,
; so a window can never become unreachable.
; ---------------------------------------------------------------------------
class TrayHider {
    ; hwnd -> Map() with "title", "process", "pid", "minimized"
    static Items := Map()
    static Watcher := ""

    static HideActive() {
        hwnd := WinExist( "A" )

        if !WindowIsManageable( hwnd ) {
            ShowToolTip(
                Lang( "MSG_TRAY_HIDE_UNSUPPORTED", "This window cannot be hidden." ),
                1800
            )
            return
        }

        ; Pressing the shortcut on an already hidden window (for example after
        ; restoring it and pressing again) is a no-op instead of an error.
        if this.Items.Has( hwnd )
            return

        ; Read the description while the window is still visible.
        info := Map(
            "title", WindowSafeTitle( hwnd ),
            "process", WindowSafeProcessName( hwnd ),
            "pid", WindowSafePid( hwnd ),
            "minimized", this.IsMinimized( hwnd )
        )

        try
            WinHide( "ahk_id " hwnd )
        catch {
            ShowToolTip(
                Lang( "MSG_TRAY_HIDE_UNSUPPORTED", "This window cannot be hidden." ),
                1800
            )
            return
        }

        ; WinHide() is a best-effort request: protected and container windows
        ; can ignore it. Confirm the window really disappeared before it is
        ; listed as hidden, otherwise the entry would look restored while the
        ; window is still on screen.
        if WindowIsVisible( hwnd ) {
            ShowToolTip(
                Lang( "MSG_TRAY_HIDE_UNSUPPORTED", "This window cannot be hidden." ),
                1800
            )
            return
        }

        this.Items[ hwnd ] := info
        this.StartWatcher()

        OSD.ShowNotification(
            "🙈 " Lang(
                "MSG_TRAY_HIDDEN",
                "Window hidden — restore it from the CapsLock- tray menu"
            ),
            2200,
            "success"
        )
    }

    static Restore( hwnd, silent := false ) {
        if !this.Items.Has( hwnd )
            return

        title := this.Items[ hwnd ][ "title" ]
        wasMinimized := this.Items[ hwnd ][ "minimized" ]
        this.Items.Delete( hwnd )

        restored := false

        if WindowHandleAlive( hwnd ) {
            try {
                WinShow( "ahk_id " hwnd )

                if wasMinimized || WinGetMinMax( "ahk_id " hwnd ) == -1
                    WinRestore( "ahk_id " hwnd )

                WinActivate( "ahk_id " hwnd )
                restored := true
            } catch {
                restored := false
            }
        }

        if this.Items.Count == 0
            this.StopWatcher()

        if silent
            return

        if restored {
            OSD.ShowNotification(
                "👁 " Lang( "MSG_TRAY_RESTORED", "Window restored: {1}", title ),
                1800,
                "info"
            )
        } else {
            ShowToolTip(
                Lang( "MSG_TRAY_WINDOW_GONE", "The hidden window is no longer available." ),
                1800
            )
        }
    }

    ; Bring every hidden window back. Used by the tray menu and on exit so a
    ; running application is never left invisible.
    static RestoreAll( silent := false ) {
        if this.Items.Count == 0
            return

        for hwnd, info in this.Items.Clone()
            this.Restore( hwnd, silent )
    }

    static Count() {
        return this.Items.Count
    }

    ; --- Tray menu integration -------------------------------------------

    ; Children for the "Hidden windows" tray entry. CustomMenu only needs
    ; label / callback / isSep entries, so the list is built on demand.
    static MenuItems() {
        children := []

        if this.Items.Count == 0 {
            children.Push({
                label: "· " Lang( "MENU_HIDDEN_NONE", "No hidden windows" ),
                callback: (*) => 0
            })

            return children
        }

        for hwnd, info in this.Items {
            children.Push({
                label: this.MenuLabel( info ),
                callback: this.MakeRestoreCallback( hwnd )
            })
        }

        children.Push({ isSep: true })
        children.Push({
            label: "↩ " Lang( "MENU_HIDDEN_RESTORE_ALL", "Restore all hidden windows" ),
            callback: (*) => TrayHider.RestoreAll()
        })

        return children
    }

    ; The callback is built in its own function so every row captures its own
    ; window handle instead of the loop variable.
    static MakeRestoreCallback( hwnd ) {
        return ((*) => TrayHider.Restore( hwnd ))
    }

    ; Tray rows stay short: title (trimmed) plus the owning process.
    static MenuLabel( info ) {
        title := info[ "title" ]

        if StrLen( title ) > 34
            title := SubStr( title, 1, 34 ) "…"

        process := info[ "process" ]

        return "🫥 " title ( process != "" ? "  (" process ")" : "" )
    }

    ; --- Helpers ----------------------------------------------------------

    static IsMinimized( hwnd ) {
        try
            return WinGetMinMax( "ahk_id " hwnd ) == -1
        catch
            return false
    }

    ; --- Session housekeeping --------------------------------------------

    static StartWatcher() {
        if this.Watcher != ""
            return

        this.Watcher := ObjBindMethod( this, "PruneClosedWindows" )
        SetTimer( this.Watcher, 2000 )
    }

    static StopWatcher() {
        if this.Watcher == ""
            return

        SetTimer( this.Watcher, 0 )
        this.Watcher := ""
    }

    ; Drop entries whose window was closed while hidden so the tray list only
    ; offers windows that can actually be restored.
    static PruneClosedWindows() {
        if this.Items.Count == 0 {
            this.StopWatcher()
            return
        }

        for hwnd, info in this.Items.Clone() {
            if !WindowHandleAlive( hwnd )
                this.Items.Delete( hwnd )
        }

        if this.Items.Count == 0
            this.StopWatcher()
    }
}
