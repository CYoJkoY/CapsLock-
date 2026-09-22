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

    ; Match the settling delay used by the existing ActivateAndPaste() path.
    ; Generic/custom editors may need time to restore their application-level
    ; caret after their top-level window becomes active.
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
        ; the clipboard.
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

        ; Do not call ControlFocus for custom/non-edit controls. Chromium,
        ; Electron and other virtualized editors often represent their editing
        ; surface with an implementation detail HWND which is not the actual
        ; application-level caret target. Re-focusing that child can destroy
        ; the internal caret/selection state that the restored top-level window
        ; would otherwise preserve.
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
                controlRestored: false,
                error: ""
            }

        ; Generic/custom controls receive the same foreground Ctrl+V path used
        ; by the established history/file paste workflow. Keep the full
        ; settling delay rather than attempting to force a child focus.
        Sleep(this.ForegroundSettleDelay)

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
