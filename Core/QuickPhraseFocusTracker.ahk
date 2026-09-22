#Requires AutoHotkey v2.0

class QuickPhraseFocusTracker {
    static Interval := 25
    static Initialized := false

    static Initialize() {
        if this.Initialized
            return

        this.Initialized := true
        SetTimer(
            QuickPhraseFocusTrackerUpdate,
            this.Interval
        )
    }
}

QuickPhraseFocusTrackerUpdate() {
    if !AppState.QuickPhraseTransactionActive
        return

    target := AppState.QuickPhrasePasteTarget
    if !IsObject(target)
        return

    currentWindow := WinExist("A")
    if !currentWindow || QuickPhraseIsInternalWindow(currentWindow)
        return

    currentControl := 0
    try
        currentControl := ControlGetFocus("ahk_id " currentWindow)
    catch
        currentControl := 0

    ; Keep the same target object reference used by QuickPhraseExecutePhrase().
    ; Only its destination changes, so the final paste always follows the
    ; latest non-Quick-Phrase focus rather than the window captured at entry.
    target.window := currentWindow
    target.control := currentControl
}

QuickPhraseIsInternalWindow(hwnd) {
    if !hwnd
        return true

    if IsObject(AppState.QuickPhraseGui) {
        try {
            if AppState.QuickPhraseGui.Hwnd == hwnd
                return true
        } catch {
        }
    }

    if IsObject(AppState.QuickPhraseVariableGui) {
        try {
            if AppState.QuickPhraseVariableGui.Hwnd == hwnd
                return true
        } catch {
        }
    }

    if IsObject(AppState.QuickPhraseManagerGui) {
        try {
            if AppState.QuickPhraseManagerGui.Hwnd == hwnd
                return true
        } catch {
        }
    }

    return false
}
