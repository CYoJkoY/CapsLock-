#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Borderless fullscreen for the active window (CapsLock + Shift + W).
;
; The window frame (title bar, system menu buttons and the resizable border)
; is removed and the window is resized to the full rectangle of the monitor it
; currently sits on, so it also covers the taskbar.
;
; Everything needed to undo the change is recorded per window:
;   - window style and extended style bits
;   - restore position and size
;   - maximized state
;   - whether the window was already top-most
;
; Pressing CapsLock + Shift + W again restores that recorded state, so the
; switch is fully reversible. Sessions are dropped automatically when the
; window is closed, and every session is restored when the script exits.
; ---------------------------------------------------------------------------
class WindowFullScreen {
    ; hwnd -> Map() with the recorded window state
    static Sessions := Map()
    static Watcher := ""

    ; --- Style constants -------------------------------------------------
    static GWL_STYLE := -16
    static GWL_EXSTYLE := -20

    static WS_CAPTION := 0x00C00000
    static WS_MAXIMIZEBOX := 0x00010000
    static WS_MINIMIZEBOX := 0x00020000
    static WS_THICKFRAME := 0x00040000
    static WS_EX_TOPMOST := 0x00000008

    ; --- SetWindowPos ----------------------------------------------------
    static HWND_TOPMOST := -1
    static HWND_NOTOPMOST := -2
    static SWP_FRAMECHANGED := 0x0020
    static SWP_SHOWWINDOW := 0x0040

    static Toggle() {
        hwnd := WinExist( "A" )

        if !WindowIsManageable( hwnd ) {
            ShowToolTip(
                Lang(
                    "MSG_BORDERLESS_UNSUPPORTED",
                    "This window cannot be switched to borderless fullscreen."
                ),
                1800
            )
            return
        }

        if this.Sessions.Has( hwnd )
            this.Restore( hwnd )
        else
            this.Enter( hwnd )
    }

    ; True while hwnd is currently displayed in borderless fullscreen.
    static IsActive( hwnd ) {
        return this.Sessions.Has( hwnd )
    }

    static IsSupported( hwnd ) {
        return WindowIsManageable( hwnd )
    }

    static Enter( hwnd ) {
        ; A maximized or minimized window reports the wrong restore rectangle,
        ; so leave that state first and read the geometry afterwards.
        wasMaximized := false

        try {
            state := WinGetMinMax( "ahk_id " hwnd )

            if state != 0 {
                if state == 1
                    wasMaximized := true

                WinRestore( "ahk_id " hwnd )
                Sleep( 60 )
            }
        } catch {
        }

        style := 0
        exStyle := 0
        x := 0
        y := 0
        w := 0
        h := 0

        try {
            style := this.GetWindowLong( hwnd, this.GWL_STYLE )
            exStyle := this.GetWindowLong( hwnd, this.GWL_EXSTYLE )
            WinGetPos( &x, &y, &w, &h, "ahk_id " hwnd )
        } catch {
            ShowToolTip(
                Lang(
                    "MSG_BORDERLESS_UNSUPPORTED",
                    "This window cannot be switched to borderless fullscreen."
                ),
                1800
            )
            return
        }

        ; Fall back to the primary monitor when the monitor rectangle cannot be
        ; read (remote sessions, virtual desktops, protected windows).
        if !this.GetMonitorRect( hwnd, &mL, &mT, &mR, &mB ) {
            mL := 0
            mT := 0
            mR := A_ScreenWidth
            mB := A_ScreenHeight
        }

        ; Keep WS_SYSMENU (0x00080000) so Alt + Space still works while the
        ; window has no visible frame.
        frameStyle := style & ~this.WS_CAPTION & ~this.WS_THICKFRAME & ~this.WS_MAXIMIZEBOX & ~this.WS_MINIMIZEBOX

        wasTopmost := ( exStyle & this.WS_EX_TOPMOST ) != 0

        try {
            this.SetWindowLong( hwnd, this.GWL_STYLE, frameStyle )

            ; HWND_TOPMOST keeps the window above the taskbar while it covers
            ; the whole monitor; the flag is dropped again on restore.
            DllCall(
                "user32\SetWindowPos",
                "Ptr", hwnd,
                "Ptr", this.HWND_TOPMOST,
                "Int", mL,
                "Int", mT,
                "Int", mR - mL,
                "Int", mB - mT,
                "UInt",
                this.SWP_FRAMECHANGED | this.SWP_SHOWWINDOW
            )
        } catch {
            ShowToolTip(
                Lang(
                    "MSG_BORDERLESS_UNSUPPORTED",
                    "This window cannot be switched to borderless fullscreen."
                ),
                1800
            )
            return
        }

        this.Sessions[ hwnd ] := Map(
            "style", style,
            "exStyle", exStyle,
            "x", x,
            "y", y,
            "w", w,
            "h", h,
            "maximized", wasMaximized,
            "topmost", wasTopmost
        )

        this.StartWatcher()
        WinActivate( "ahk_id " hwnd )
        OSD.ShowNotification(
            "🖥 " Lang( "MSG_BORDERLESS_ON", "Borderless fullscreen" ),
            1500,
            "success"
        )
    }

    static Restore( hwnd, silent := false ) {
        if !this.Sessions.Has( hwnd )
            return

        session := this.Sessions[ hwnd ]
        this.Sessions.Delete( hwnd )

        if WindowHandleAlive( hwnd ) {
            try {
                this.SetWindowLong( hwnd, this.GWL_STYLE, session[ "style" ] )
                this.SetWindowLong( hwnd, this.GWL_EXSTYLE, session[ "exStyle" ] )

                ; HWND_NOTOPMOST clears WS_EX_TOPMOST for windows that were not
                ; top-most before the switch.
                DllCall(
                    "user32\SetWindowPos",
                    "Ptr", hwnd,
                    "Ptr", session[ "topmost" ] ? this.HWND_TOPMOST : this.HWND_NOTOPMOST,
                    "Int", session[ "x" ],
                    "Int", session[ "y" ],
                    "Int", session[ "w" ],
                    "Int", session[ "h" ],
                    "UInt", this.SWP_FRAMECHANGED
                )

                if session[ "maximized" ]
                    WinMaximize( "ahk_id " hwnd )
            } catch {
            }
        }

        if this.Sessions.Count == 0
            this.StopWatcher()

        if !silent {
            OSD.ShowNotification(
                "🖥 " Lang( "MSG_BORDERLESS_OFF", "Windowed" ),
                1500,
                "info"
            )
        }
    }

    ; Restore every borderless session. Used on exit / reload so no window is
    ; left frameless behind.
    static RestoreAll( silent := false ) {
        if this.Sessions.Count == 0
            return

        for hwnd, session in this.Sessions.Clone()
            this.Restore( hwnd, silent )
    }

    ; --- Low level helpers -----------------------------------------------

    static GetWindowLong( hwnd, index ) {
        return DllCall(
            "user32\GetWindowLongPtrW",
            "Ptr", hwnd,
            "Int", index,
            "Ptr"
        )
    }

    static SetWindowLong( hwnd, index, value ) {
        return DllCall(
            "user32\SetWindowLongPtrW",
            "Ptr", hwnd,
            "Int", index,
            "Ptr", value,
            "Ptr"
        )
    }

    ; Full rectangle (including the taskbar area) of the monitor that contains
    ; the largest part of hwnd. Returns false when the rectangle is unusable.
    static GetMonitorRect( hwnd, &left, &top, &right, &bottom ) {
        left := 0
        top := 0
        right := 0
        bottom := 0

        try {
            ; MONITOR_DEFAULTTONEAREST
            monitor := DllCall(
                "user32\MonitorFromWindow",
                "Ptr", hwnd,
                "UInt", 2,
                "Ptr"
            )

            if !monitor
                return false

            ; MONITORINFO: cbSize + rcMonitor + rcWork + dwFlags
            info := Buffer( 40, 0 )
            NumPut( "UInt", 40, info )

            if !DllCall( "user32\GetMonitorInfoW", "Ptr", monitor, "Ptr", info, "Int" )
                return false

            left := NumGet( info, 4, "Int" )
            top := NumGet( info, 8, "Int" )
            right := NumGet( info, 12, "Int" )
            bottom := NumGet( info, 16, "Int" )

            return right > left && bottom > top
        } catch
            return false
    }

    ; --- Session housekeeping --------------------------------------------
    ; Closed windows are removed from the session map so a recycled handle can
    ; never inherit the state of a previous window.

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

    static PruneClosedWindows() {
        if this.Sessions.Count == 0 {
            this.StopWatcher()
            return
        }

        for hwnd, session in this.Sessions.Clone() {
            if !WindowHandleAlive( hwnd )
                this.Sessions.Delete( hwnd )
        }

        if this.Sessions.Count == 0
            this.StopWatcher()
    }
}
