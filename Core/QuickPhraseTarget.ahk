#Requires AutoHotkey v2.0

class QuickPhraseTarget {
    static Capture() {
        windowHwnd := WinExist("A")

        if !windowHwnd
            return ""

        if this._IsInternalWindow(windowHwnd)
            return ""

        controlHwnd := 0
        try
            controlHwnd := ControlGetFocus("ahk_id " windowHwnd)
        catch
            controlHwnd := 0

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

        currentThreadId := DllCall(
            "GetCurrentThreadId",
            "UInt"
        )

        targetThreadId := DllCall(
            "GetWindowThreadProcessId",
            "Ptr", target.window,
            "UInt", 0
        )

        if !targetThreadId
            return false

        attached := false

        try {
            if targetThreadId != currentThreadId {
                if !DllCall(
                    "AttachThreadInput",
                    "UInt", currentThreadId,
                    "UInt", targetThreadId,
                    "Int", true
                )
                    return false

                attached := true
            }

            DllCall(
                "SetFocus",
                "Ptr", target.control,
                "Ptr"
            )

            return this._IsFocusedControl(target)
        } catch {
            return false
        } finally {
            if attached {
                DllCall(
                    "AttachThreadInput",
                    "UInt", currentThreadId,
                    "UInt", targetThreadId,
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

        controlRestored := false

        if this.IsControlValid(target)
            controlRestored := this.RestoreControlFocus(target)

        ; The original destination is now the actual keyboard focus target,
        ; not merely a stored HWND. Send Ctrl+V through the normal foreground
        ; input path so native controls and Chromium/Electron render surfaces
        ; receive the same user-level paste gesture.
        try {
            Send("^v")
        } catch {
            return {
                ok: false,
                controlRestored: controlRestored
            }
        }

        ; Some native controls can reject a synthetic foreground key sequence
        ; while still accepting a direct WM_PASTE. Keep that as a narrow
        ; compatibility fallback after the real focus has been restored.
        if !controlRestored
            controlRestored := this.RestoreControlFocus(target)

        if (
            controlRestored
            && this._SupportsDirectPaste(target.control)
        ) {
            try {
                SendMessage(
                    0x0302,
                    0,
                    0,
                    ,
                    "ahk_id " target.control
                )
            } catch {
            }
        }

        return {
            ok: true,
            controlRestored: controlRestored
        }
    }

    static _IsFocusedControl(target) {
        if !this.IsControlValid(target)
            return false

        threadId := DllCall(
            "GetWindowThreadProcessId",
            "Ptr", target.window,
            "UInt", 0
        )

        if !threadId
            return false

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
        focusedHwnd := NumGet(
            info,
            focusOffset,
            "Ptr"
        )

        return focusedHwnd == target.control
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
