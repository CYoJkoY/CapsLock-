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

        try
            ControlFocus(
                target.control,
                "ahk_id " target.window
            )
        catch
            return false

        try
            return ControlGetFocus(
                "ahk_id " target.window
            ) == target.control
        catch
            return false
    }

    static DeliverPaste(target) {
        if !this.Activate(target)
            return {
                ok: false,
                controlRestored: false
            }

        controlRestored := this.RestoreControlFocus(target)

        try {
            Send("^v")
        } catch {
            return {
                ok: false,
                controlRestored: controlRestored
            }
        }

        return {
            ok: true,
            controlRestored: controlRestored
        }
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
