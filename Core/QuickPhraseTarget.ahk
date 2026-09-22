#Requires AutoHotkey v2.0

class QuickPhraseTarget {
    static Capture() {
        windowHwnd := WinExist("A")

        if !windowHwnd
            return ""

        return { window: windowHwnd }
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
}
