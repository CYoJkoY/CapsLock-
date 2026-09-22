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

    static DeliverPaste(target) {
        if !this.Activate(target)
            return {
                ok: false,
                controlRestored: false,
                error: "Quick Phrase target window could not be activated."
            }

        controlRestored := this.RestoreControlFocus(target)

        try {
            Send("^v")
        } catch as err {
            return {
                ok: false,
                controlRestored: controlRestored,
                error: "Quick Phrase paste failed: " err.Message
            }
        }

        return {
            ok: true,
            controlRestored: controlRestored,
            error: ""
        }
    }
}
