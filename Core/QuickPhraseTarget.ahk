#Requires AutoHotkey v2.0

class QuickPhraseTarget {
    static ForegroundSettleDelay := 100

    static Capture() {
        windowHwnd := WinExist("A")

        if !windowHwnd
            return ""

        controlHwnd := 0

        try {
            controlHwnd := ControlGetFocus("ahk_id " windowHwnd)
        } catch {
            controlHwnd := 0
        }

        return {
            window: windowHwnd,
            control: controlHwnd
        }
    }

    static IsWindowValid(target) {
        if !IsObject(target)
            return false

        try {
            windowHwnd := target.window
        } catch {
            return false
        }

        if !windowHwnd
            return false

        try {
            return WinExist("ahk_id " windowHwnd) == windowHwnd
        } catch {
            return false
        }
    }

    static IsControlValid(target) {
        if !this.IsWindowValid(target)
            return false

        try {
            controlHwnd := target.control
            windowHwnd := target.window
        } catch {
            return false
        }

        if !controlHwnd
            return false

        try {
            if WinExist("ahk_id " controlHwnd) != controlHwnd
                return false

            rootHwnd := DllCall(
                "GetAncestor",
                "Ptr", controlHwnd,
                "UInt", 2,
                "Ptr"
            )
        } catch {
            return false
        }

        return rootHwnd == windowHwnd
    }

    static Activate(target, timeout := 1) {
        if !this.IsWindowValid(target)
            return false

        try {
            WinActivate("ahk_id " target.window)
        } catch {
            return false
        }

        if !WinWaitActive("ahk_id " target.window, , timeout)
            return false

        return WinExist("A") == target.window
    }

    static RestoreControlFocus(target) {
        if !this.IsControlValid(target)
            return false

        try {
            ControlFocus(
                "ahk_id " target.control,
                "ahk_id " target.window
            )
        } catch {
            return false
        }

        try {
            return ControlGetFocus("ahk_id " target.window) == target.control
        } catch {
            return false
        }
    }

    static SendForegroundPaste() {
        try {
            Send("^v")
            return true
        } catch {
            return false
        }
    }

    static DeliverPaste(target) {
        if !this.IsWindowValid(target)
            return {
                ok: false,
                mode: "none",
                controlRestored: false,
                error: "Quick Phrase target window is no longer available."
            }

        if !this.Activate(target)
            return {
                ok: false,
                mode: "none",
                controlRestored: false,
                error: "Quick Phrase target window could not be activated."
            }

        ; Restore the exact control which had keyboard focus before Quick Phrase
        ; opened. This is important for browsers and custom editors: activating
        ; the top-level window alone may leave focus on a non-editing child or on
        ; no child at all. ControlFocus is only an attempt; invalid/unsupported
        ; controls fall back to the window's current logical focus.
        controlRestored := this.RestoreControlFocus(target)

        ; Keep the same settling interval as the established history paste
        ; workflow. The delay gives the application time to restore its editor
        ; surface/caret after cross-window activation and ControlFocus.
        Sleep(this.ForegroundSettleDelay)

        if this.SendForegroundPaste()
            return {
                ok: true,
                mode: controlRestored ? "foreground-control" : "foreground",
                controlRestored: controlRestored,
                error: ""
            }

        return {
            ok: false,
            mode: "none",
            controlRestored: controlRestored,
            error: "Quick Phrase paste failed: foreground Ctrl+V could not be sent."
        }
    }
}
