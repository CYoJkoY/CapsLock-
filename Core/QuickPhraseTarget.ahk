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

        ; Native Edit-like controls can accept the completed phrase directly.
        ; This path does not depend on foreground focus and does not change
        ; the clipboard, which is useful when the application exposes a real
        ; Windows edit control.
        if text != "" && this.IsEditLikeControl(target) {
            try {
                EditPaste(
                    text,
                    "ahk_id " target.control,
                    "ahk_id " target.window
                )
                return "editpaste"
            } catch {
                ; Fall through to the normal foreground keyboard path.
            }
        }

        ; The generic Quick Phrase path intentionally uses a real foreground
        ; Ctrl+V after restoring the captured control. Many applications use
        ; custom/virtualized editors where ControlSend can return without the
        ; application actually processing the keystroke.
        if this.RestoreControlFocus(target) {
            try {
                Send("^v")
                return "foreground-control"
            } catch {
                return false
            }
        }

        return false
    }

    static SendForegroundPaste() {
        try {
            Send("^v")
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
                controlRestored: controlMode == "foreground-control",
                error: ""
            }

        ; At this point the captured child HWND was either unavailable or not
        ; focusable. Do not treat ControlSend-to-window as proof of delivery:
        ; custom Chromium/Electron editors may silently ignore it while AHK
        ; still reports success. The target top-level window is already active,
        ; so preserve the original application's foreground Ctrl+V behavior.
        Sleep(30)

        if this.SendForegroundPaste()
            return {
                ok: true,
                mode: "foreground",
                controlRestored: false,
                error: ""
            }

        return {
            ok: false,
            mode: "none",
            controlRestored: false,
            error: "Quick Phrase paste failed: foreground Ctrl+V could not be sent."
        }
    }
}
