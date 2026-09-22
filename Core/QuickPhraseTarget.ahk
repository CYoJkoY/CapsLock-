#Requires AutoHotkey v2.0

class QuickPhraseTarget {
    static Capture() {
        windowHwnd := WinExist("A")

        if !windowHwnd
            return ""

        if this._IsInternalWindow(windowHwnd)
            return ""

        controlHwnd := this._GetKeyboardFocus(windowHwnd)

        ; GetGUIThreadInfo is the authoritative Windows focus query. Some
        ; applications expose focus through AHK's ControlGetFocus even when
        ; GetGUIThreadInfo cannot provide a child HWND, so keep the older API
        ; as a narrow capture fallback.
        if !controlHwnd {
            try
                controlHwnd := ControlGetFocus("ahk_id " windowHwnd)
            catch
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

        try windowHwnd := target.window
        catch
            return false

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

        try controlHwnd := target.control
        catch
            return false

        if !controlHwnd
            return false

        if !WinExist("ahk_id " controlHwnd)
            return false

        try
            rootHwnd := DllCall(
                "GetAncestor",
                "Ptr", controlHwnd,
                "UInt", 2,
                "Ptr"
            )
        catch
            return false

        return rootHwnd == target.window
    }

    static Activate(target, timeout := 1) {
        if !this.IsWindowValid(target)
            return false

        try
            WinActivate("ahk_id " target.window)
        catch
            return false

        try
            return WinWaitActive(
                "ahk_id " target.window,
                ,
                timeout
            ) == target.window
        catch
            return false
    }

    static RestoreControlFocus(target) {
        if !this.IsControlValid(target)
            return false

        controlThreadId := DllCall(
            "GetWindowThreadProcessId",
            "Ptr", target.control,
            "UInt", 0
        )

        currentThreadId := DllCall(
            "GetCurrentThreadId",
            "UInt"
        )

        if !controlThreadId
            return false

        if controlThreadId == currentThreadId
            return this._SetAndVerifyFocus(
                target.control,
                controlThreadId
            )

        attached := false

        try {
            if !DllCall(
                "AttachThreadInput",
                "UInt", currentThreadId,
                "UInt", controlThreadId,
                "Int", true
            )
                return false

            attached := true

            return this._SetAndVerifyFocus(
                target.control,
                controlThreadId
            )
        } catch {
            return false
        } finally {
            if attached {
                DllCall(
                    "AttachThreadInput",
                    "UInt", currentThreadId,
                    "UInt", controlThreadId,
                    "Int", false
                )
            }
        }
    }

    static DeliverPaste(target) {
        if !this.IsWindowValid(target)
            return {
                ok: false,
                controlRestored: false
            }

        if !this.Activate(target)
            return {
                ok: false,
                controlRestored: false
            }

        controlValid := this.IsControlValid(target)
        controlRestored := false

        if controlValid
            controlRestored := this.RestoreControlFocus(target)

        ; Never send Ctrl+V until the captured keyboard focus has been restored.
        ; Sending while the Quick Phrase GUI still owns focus is the failure mode
        ; this target abstraction is intended to eliminate.
        if controlRestored {
            try {
                Send("^v")
            } catch {
                return {
                    ok: false,
                    controlRestored: true
                }

            return {
                ok: true,
                controlRestored: true
            }
        }

        ; A native text control can still receive WM_PASTE directly when focus
        ; restoration is unavailable. This keeps the paste tied to the original
        ; control rather than falling through to whichever window is active.
        if controlValid && this._SupportsDirectPaste(target.control) {
            try {
                SendMessage(
                    0x0302,
                    0,
                    0,
                    ,
                    "ahk_id " target.control
                )

                return {
                    ok: true,
                    controlRestored: false
                }
            } catch {
            }
        }

        ; If the exact original child still exists but Windows would not let us
        ; restore its focus, address that child directly instead of sending to
        ; the current foreground window. ControlSend is the final child-targeted
        ; fallback for custom controls that do not implement native WM_PASTE.
        if controlValid {
            try {
                ControlSend(
                    "^v",
                    target.control,
                    "ahk_id " target.window
                )

                return {
                    ok: true,
                    controlRestored: false
                }
            } catch {
                return {
                    ok: false,
                    controlRestored: false
                }
            }
        }

        ; Only a target without a usable original child control may fall back to
        ; the top-level foreground paste path. This prevents Quick Phrase's own
        ; GUI from accidentally receiving Ctrl+V when a captured child exists.
        try {
            Send("^v")
            return {
                ok: true,
                controlRestored: false
            }
        } catch {
            return {
                ok: false,
                controlRestored: false
            }
        }
    }

    static _GetKeyboardFocus(windowHwnd) {
        threadId := DllCall(
            "GetWindowThreadProcessId",
            "Ptr", windowHwnd,
            "UInt", 0
        )

        if !threadId
            return 0

        info := Buffer(A_PtrSize == 8 ? 72 : 48, 0)

        NumPut(
            "UInt",
            info.Size,
            info,
            0
        )

        if !DllCall(
            "GetGUIThreadInfo",
            "UInt", threadId,
            "Ptr", info.Ptr,
            "Int"
        )
            return 0

        focusOffset := A_PtrSize == 8 ? 16 : 12

        return NumGet(
            info,
            focusOffset,
            "Ptr"
        )
    }

    static _SetAndVerifyFocus(controlHwnd, threadId) {
        DllCall(
            "SetFocus",
            "Ptr", controlHwnd,
            "Ptr"
        )

        info := Buffer(A_PtrSize == 8 ? 72 : 48, 0)

        NumPut(
            "UInt",
            info.Size,
            info,
            0
        )

        if !DllCall(
            "GetGUIThreadInfo",
            "UInt", threadId,
            "Ptr", info.Ptr,
            "Int"
        )
            return false

        focusOffset := A_PtrSize == 8 ? 16 : 12

        return NumGet(
            info,
            focusOffset,
            "Ptr"
        ) == controlHwnd
    }

    static _SupportsDirectPaste(hwnd) {
        try
            className := StrUpper(WinGetClass("ahk_id " hwnd))
        catch
            return false

        return (
            InStr(className, "EDIT")
            || InStr(className, "RICHEDIT")
            || InStr(className, "SCINTILLA")
            || InStr(className, "TMEMO")
            || InStr(className, "TEDIT")
        )
    }

    static _IsInternalWindow(hwnd) {
        if IsObject(AppState.QuickPhraseGui) {
            try {
                if AppState.QuickPhraseGui.Hwnd == hwnd
                    return true
            }
        }

        if IsObject(AppState.QuickPhraseVariableGui) {
            try {
                if AppState.QuickPhraseVariableGui.Hwnd == hwnd
                    return true
            }
        }

        if IsObject(AppState.QuickPhraseManagerGui) {
            try {
                if AppState.QuickPhraseManagerGui.Hwnd == hwnd
                    return true
            }
        }

        if IsSet(CustomMenu) {
            try {
                if CustomMenu.menuHwnd == hwnd
                    return true
            }
        }

        if IsObject(AppState.FullHistoryGui) {
            try {
                if AppState.FullHistoryGui.Hwnd == hwnd
                    return true
            }
        }

        return false
    }
}
