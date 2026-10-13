#Requires AutoHotkey v2.0

; Per-executable rules for the CapsLock modifier layer.
; Unknown foreground-window state fails open to preserve existing behavior.
class ApplicationProfiles {
    static NormalizeExecutableName(processName) {
        executableName := StrLower(Trim(String(processName)))
        if (executableName == "" || !RegExMatch(executableName, 'i)^[^\\/:*?"<>|]+\.exe$'))
            return ""
        return executableName
    }

    static NormalizeDisabledExecutables(value) {
        sourceValues := value is Array ? value : StrSplit(String(value), "|")
        normalizedValues := []
        seenExecutables := Map()

        for rawValue in sourceValues {
            executableName := this.NormalizeExecutableName(rawValue)
            if (executableName == "" || seenExecutables.Has(executableName))
                continue

            seenExecutables[executableName] := true
            normalizedValues.Push(executableName)
        }

        return normalizedValues
    }

    static IsHotkeysEnabledForActiveWindow(windowHwnd := 0) {
        if !windowHwnd
            windowHwnd := WinExist("A")
        if !windowHwnd
            return true

        try {
            executableName := this.NormalizeExecutableName(
                WinGetProcessName("ahk_id " windowHwnd)
            )
        } catch {
            return true
        }

        if executableName == ""
            return true

        for disabledExecutable in AppState.DisabledHotkeyProcesses {
            if executableName == disabledExecutable
                return false
        }

        return true
    }

    static AddDisabledExecutable(processName) {
        executableName := this.NormalizeExecutableName(processName)
        if executableName == ""
            return false

        for currentExecutable in AppState.DisabledHotkeyProcesses {
            if currentExecutable == executableName
                return false
        }

        previousExecutables := AppState.DisabledHotkeyProcesses
        nextExecutables := previousExecutables.Clone()
        nextExecutables.Push(executableName)
        AppState.DisabledHotkeyProcesses := nextExecutables

        try {
            ConfigManager.Save(false)
        } catch as caughtError {
            AppState.DisabledHotkeyProcesses := previousExecutables
            throw caughtError
        }

        return true
    }

    static RemoveDisabledExecutable(processName) {
        executableName := this.NormalizeExecutableName(processName)
        if executableName == ""
            return false

        previousExecutables := AppState.DisabledHotkeyProcesses
        nextExecutables := []
        wasRemoved := false

        for currentExecutable in previousExecutables {
            if !wasRemoved && currentExecutable == executableName {
                wasRemoved := true
                continue
            }
            nextExecutables.Push(currentExecutable)
        }

        if !wasRemoved
            return false

        AppState.DisabledHotkeyProcesses := nextExecutables
        try {
            ConfigManager.Save(false)
        } catch as caughtError {
            AppState.DisabledHotkeyProcesses := previousExecutables
            throw caughtError
        }

        return true
    }
}
