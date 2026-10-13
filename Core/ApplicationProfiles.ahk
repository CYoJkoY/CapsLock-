#Requires AutoHotkey v2.0

; Per-executable rules for the CapsLock modifier layer.
; Unknown foreground-window state fails open to preserve existing behavior.
class ApplicationProfiles {
    static ShortcutGroups := [
        {id: "text", labelKey: "GUI_APP_PROFILES_GROUP_TEXT"},
        {id: "clipboard", labelKey: "GUI_APP_PROFILES_GROUP_CLIPBOARD"},
        {id: "window", labelKey: "GUI_APP_PROFILES_GROUP_WINDOW"},
        {id: "tabs", labelKey: "GUI_APP_PROFILES_GROUP_TABS"},
        {id: "visual", labelKey: "GUI_APP_PROFILES_GROUP_VISUAL"},
        {id: "tools", labelKey: "GUI_APP_PROFILES_GROUP_TOOLS"},
        {id: "quickphrase", labelKey: "GUI_APP_PROFILES_GROUP_QUICK_PHRASE"}
    ]

    static GetShortcutGroups() {
        return this.ShortcutGroups
    }

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

    ; Format: executable.exe:group1,group2|another.exe:group3
    ; ':' and '|' cannot occur in a Windows executable basename.
    static NormalizeDisabledGroups(value) {
        sourceRules := value is Array ? value : StrSplit(String(value), "|")
        normalizedRules := Map()

        for rawRule in sourceRules {
            separatorPosition := InStr(rawRule, ":")
            if separatorPosition <= 1
                continue

            executableName := this.NormalizeExecutableName(
                SubStr(rawRule, 1, separatorPosition - 1)
            )
            if executableName == ""
                continue

            groupIds := this.NormalizeShortcutGroups(
                StrSplit(SubStr(rawRule, separatorPosition + 1), ",")
            )
            if groupIds.Length == 0
                continue

            normalizedRules[executableName] := groupIds
        }

        return normalizedRules
    }

    static NormalizeShortcutGroups(value) {
        sourceGroups := value is Array ? value : StrSplit(String(value), ",")
        requestedGroups := Map()
        for rawGroup in sourceGroups {
            groupId := StrLower(Trim(String(rawGroup)))
            if groupId != ""
                requestedGroups[groupId] := true
        }

        normalizedGroups := []
        for definition in this.ShortcutGroups {
            if requestedGroups.Has(definition.id)
                normalizedGroups.Push(definition.id)
        }

        return normalizedGroups
    }

    static NormalizeShortcutGroup(value) {
        groupId := StrLower(Trim(String(value)))
        for definition in this.ShortcutGroups {
            if definition.id == groupId
                return groupId
        }
        return ""
    }

    static SerializeDisabledGroups(value) {
        if !(value is Map)
            return ""

        serializedRules := []
        for rawExecutableName, rawGroups in value {
            executableName := this.NormalizeExecutableName(rawExecutableName)
            groupIds := this.NormalizeShortcutGroups(rawGroups)
            if executableName == "" || groupIds.Length == 0
                continue

            serializedRules.Push(executableName ":" Join(groupIds, ","))
        }

        return Join(serializedRules, "|")
    }

    static GetDisabledGroups(processName) {
        executableName := this.NormalizeExecutableName(processName)
        if executableName == "" || !(AppState.DisabledHotkeyGroups is Map)
            return []

        if !AppState.DisabledHotkeyGroups.Has(executableName)
            return []

        return AppState.DisabledHotkeyGroups[executableName].Clone()
    }

    static SetDisabledGroups(processName, groupIds) {
        executableName := this.NormalizeExecutableName(processName)
        if executableName == ""
            return false

        normalizedGroups := this.NormalizeShortcutGroups(groupIds)
        previousRules := AppState.DisabledHotkeyGroups
        nextRules := previousRules.Clone()

        if normalizedGroups.Length == 0 {
            if nextRules.Has(executableName)
                nextRules.Delete(executableName)
        } else {
            nextRules[executableName] := normalizedGroups
        }

        AppState.DisabledHotkeyGroups := nextRules
        try {
            ; Application profiles are device-local and must not dirty Cloud Sync.
            ConfigManager.Save(false)
        } catch as caughtError {
            AppState.DisabledHotkeyGroups := previousRules
            throw caughtError
        }

        return true
    }

    static GetExecutableNameForWindow(windowHwnd := 0) {
        if !windowHwnd
            windowHwnd := WinExist("A")
        if !windowHwnd
            return ""

        try {
            return this.NormalizeExecutableName(
                WinGetProcessName("ahk_id " windowHwnd)
            )
        } catch {
            return ""
        }
    }

    static IsHotkeysEnabledForActiveWindow(windowHwnd := 0) {
        executableName := this.GetExecutableNameForWindow(windowHwnd)
        if executableName == ""
            return true

        for disabledExecutable in AppState.DisabledHotkeyProcesses {
            if executableName == disabledExecutable
                return false
        }

        return true
    }

    static IsShortcutGroupEnabledForActiveWindow(group, windowHwnd := 0) {
        groupId := this.NormalizeShortcutGroup(group)
        if groupId == ""
            return true

        executableName := this.GetExecutableNameForWindow(windowHwnd)
        if executableName == ""
            return true

        for disabledExecutable in AppState.DisabledHotkeyProcesses {
            if executableName == disabledExecutable
                return false
        }

        disabledGroupsByExecutable := AppState.DisabledHotkeyGroups
        if !(disabledGroupsByExecutable is Map)
            return true
        if !disabledGroupsByExecutable.Has(executableName)
            return true

        for disabledGroup in disabledGroupsByExecutable[executableName] {
            if disabledGroup == groupId
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
