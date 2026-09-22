#Requires AutoHotkey v2.0

class QuickPhraseTarget {
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

    static SendToControl(target) {
        if !this.IsControlValid(target)
            return false

        ; ControlSend is the primary delivery path because it targets the HWND
        ; captured before Quick Phrase opened any GUI. Restoring focus first
        ; keeps controls that only accept keyboard paste after focus compatible.
        if !this.RestoreControlFocus(target)
            return false

        try {
            ControlSend(
                "^v",
                "ahk_id " target.control,
                "ahk_id " target.window
            )
            return true
        } catch {
            return false
        }
    }

    static SendToWindow(target) {
        if !this.IsWindowValid(target)
            return false

        try {
            ControlSend(
                "^v",
                "",
                "ahk_id " target.window
            )
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

        ; Re-establish the original top-level window before delivery. This is
        ; important for controls that require the application to own the
        ; foreground session, while ControlSend still pins the keystroke to
        ; the captured target instead of whichever Quick Phrase GUI is active.
        if !this.Activate(target)
            return {
                ok: false,
                mode: "none",
                controlRestored: false,
                error: "Quick Phrase target window could not be activated."
            }

        if this.SendToControl(target)
            return {
                ok: true,
                mode: "control",
                controlRestored: true,
                error: ""
            }

        ; The original control may have been destroyed or may reject
        ; ControlSend. Fall back to the original top-level window.
        if this.SendToWindow(target)
            return {
                ok: true,
                mode: "window",
                controlRestored: false,
                error: ""
            }

        ; Preserve the compatibility behavior used by the rest of the
        ; application for custom/Chromium/Electron targets. The window has
        ; already been confirmed active, so this final fallback does not
        ; depend on the Quick Phrase GUI remaining in the foreground.
        try {
            Send("^v")
            return {
                ok: true,
                mode: "foreground",
                controlRestored: false,
                error: ""
            }
        } catch as err {
            return {
                ok: false,
                mode: "none",
                controlRestored: false,
                error: "Quick Phrase paste failed: " err.Message
            }
        }
    }
}
