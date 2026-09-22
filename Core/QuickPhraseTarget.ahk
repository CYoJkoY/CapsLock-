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

    static IsCapturedControlFocused(target) {
        if !this.IsControlValid(target)
            return false

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

        ; Do not force ControlFocus here. Chromium, VS Code, Electron and other
        ; custom editor surfaces can expose implementation-specific child HWNDs;
        ; forcing one can move keyboard focus away from the editor/caret that
        ; the application itself restores when its top-level window activates.
        ; We only inspect whether the originally focused child has naturally
        ; been restored, then use the established foreground Ctrl+V path.
        controlRestored := this.IsCapturedControlFocused(target)

        ; Keep the same settling interval as the established history paste
        ; workflow so the target application can restore its editor surface
        ; and caret after cross-window activation.
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
