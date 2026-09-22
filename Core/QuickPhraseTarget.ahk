#Requires AutoHotkey v2.0

class QuickPhraseTarget {
    static EditControlClassPrefixes := [
        "Edit",
        "RichEdit",
        "Scintilla",
        "TMemo",
        "TSyntaxMemo",
        "AkelEdit",
        "TJvRichEdit",
        "TEdit",
        "EditControl"
    ]
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

    static IsEditLikeControl(target) {
        if !this.IsControlValid(target)
            return false

        try {
            className := WinGetClass("ahk_id " target.control)
        } catch {
            return false
        }

        classNameLower := StrLower(className)

        for knownClass in this.EditControlClassPrefixes {
            knownClassLower := StrLower(knownClass)

            if (
                classNameLower == knownClassLower
                || InStr(classNameLower, knownClassLower) == 1
            ) {
                return true
            }
        }

        return false
    }

    static SendToControl(target, text := "") {
        if !this.IsControlValid(target)
            return false

        ; Native Edit-like controls have a dedicated paste API. It writes the
        ; supplied text at the control's caret without depending on foreground
        ; focus and without modifying the clipboard.
        if text != "" && this.IsEditLikeControl(target) {
            try {
                EditPaste(
                    text,
                    "ahk_id " target.control,
                    "ahk_id " target.window
                )
                return "editpaste"
            } catch {
                ; Fall through to the focused-control keyboard path for
                ; modified/custom edit implementations which reject EditPaste.
            }
        }

        ; When the captured control can be focused again, prefer a real
        ; foreground Ctrl+V. This preserves the application's normal input
        ; pipeline and is more compatible with custom/virtualized editors than
        ; treating a successful ControlSend call as proof that the application
        ; processed the paste.
        if this.RestoreControlFocus(target) {
            try {
                Send("^v")
                return "foreground-control"
            } catch {
                ; Fall through to ControlSend.
            }
        }

        try {
            ControlSend(
                "^v",
                "ahk_id " target.control,
                "ahk_id " target.window
            )
            return "controlsend"
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

    static DeliverPaste(target, text := "") {
        if !this.IsWindowValid(target)
            return {
                ok: false,
                mode: "none",
                controlRestored: false,
                error: "Quick Phrase target window is no longer available."
            }

        ; Re-establish the original top-level window before delivery.
        ; Foreground Send remains available for editors which do not accept
        ; ControlSend-style posted keyboard messages.
        if !this.Activate(target)
            return {
                ok: false,
                mode: "none",
                controlRestored: false,
                error: "Quick Phrase target window could not be activated."
            }

        controlMode := this.SendToControl(target, text)

        if controlMode != ""
            return {
                ok: true,
                mode: controlMode,
                controlRestored: controlMode == "controlsend",
                error: ""
            }

        ; The original control may have been destroyed or may reject
        ; EditPaste/ControlSend. Fall back to the original top-level window.
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
