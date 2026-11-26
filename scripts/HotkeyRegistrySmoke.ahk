#Requires AutoHotkey v2.0
#SingleInstance Force

; Runtime checks for configurable bindings: canonical suffix parsing, conflict
; rejection, live re-registration, persistence round-trip, and restoring
; defaults. The stubs replace the collaborators the registry only needs when a
; hotkey actually fires.
class AppState {
    static HotkeyBindings := Map()
    static QuickPhraseEnabled := true
}

class ConfigManager {
    static Save(*) {
    }
}

class HotkeySettingsGui {
    static IsCapturing() {
        return false
    }
}

class FileDeleter {
    static Busy := false

    static IsFileBrowserActive() {
        return false
    }

    static ConfirmDelete() {
    }
}

Join(values, separator := " ") {
    result := ""
    for index, value in values
        result .= (index > 1 ? separator : "") value
    return result
}

JumpToLine(*) {
}

TerminateProcessByPid(*) {
}

ToggleAlwaysOnTopWithOSD(*) {
}

CopyAsPlainTextAndAddToHistory(*) {
}

PasteWithCurrentMode(*) {
}

ShowHistoryMenu(*) {
}

ChangeCaseOfLastCopy(*) {
}

ConvertWithPandoc(*) {
}

OpenTempFolder(*) {
}

QuickPhraseHandleHotkey(*) {
}

WindowWildcardMaximize(*) {
}

WindowWildcardMinimize(*) {
}

DeactivateShiftLayer(*) {
}

AdjustOpacityShortcut(*) {
}

ToggleGhostOpacity(*) {
}

CapsLockShortcutGroupAvailable(*) {
    return true
}

WindowOpacityHotkeysAvailable(*) {
    return true
}

QuickPhraseUiActive(*) {
    return false
}

class WindowSwitcherGui {
    static Show(*) {
    }
}

class CommandPaletteGui {
    static Show(*) {
    }
}

class HotkeyReferenceGui {
    static Toggle(*) {
    }
}

class SettingsGui {
    static Toggle(*) {
    }
}

class ImageToolsGui {
    static Toggle(*) {
    }
}

class Spotlight {
    static HandleDown(*) {
    }

    static HandleUp(*) {
    }
}

class Zoom {
    static HandleDown(*) {
    }

    static HandleUp(*) {
    }
}

class WindowHole {
    static HandleXDown(*) {
    }

    static HandleXUp(*) {
    }
}

class WindowFullScreen {
    static Toggle(*) {
    }
}

class TrayHider {
    static HideActive(*) {
    }
}

#Include "..\Hotkeys\HotkeyRegistry.ahk"

Fail(message) {
    FileAppend("FAIL: " message "`n", "*")
    ExitApp(1)
}

Check(condition, message) {
    if !condition
        Fail(message)
}

HotkeyRegistry.Initialize()

; Defaults are displayed with the fixed CapsLock prefix.
Check(HotkeyRegistry.GetDisplayKey("fileDelete") == "CapsLock + Shift + D",
    "file deletion should default to CapsLock + Shift + D")
Check(HotkeyRegistry.GetDisplayKey("tempFolder") == "CapsLock + Alt + Q",
    "temp folder should default to CapsLock + Alt + Q")
groupedWords := HotkeyRegistry.GetDisplayKeys(["selectWordLeft", "selectWordRight"])
Check(groupedWords == "CapsLock + Shift + Left / Right",
    "grouped displays should share the CapsLock prefix, got: " groupedWords)
Check(HotkeyRegistry.GetDisplayKey("selectCurrent") == "CapsLock + Space",
    "named keys should display with their conventional names")
Check(HotkeyRegistry.GetDisplayKey("ghost") == "CapsLock + Middle Button",
    "mouse buttons should display with their conventional names")
Check(HotkeyRegistry.DisplaySuffix("+space") == "CapsLock + Shift + Space",
    "captured suffixes should display named keys in canonical case")
Check(HotkeyRegistry.DisplaySuffix("!lbutton") == "CapsLock + Alt + Left Button",
    "captured mouse suffixes should display their friendly name")
groupedMaximize := HotkeyRegistry.GetDisplayKeys(["maximize", "maximize8", "maximizeNum8"])
Check(groupedMaximize == "CapsLock + W / 8 / Numpad8",
    "grouped displays should share modifiers but keep distinct key names, got: " groupedMaximize)

; Canonical modifier order and case folding.
Check(HotkeyRegistry.NormalizeSuffix("Shift+Ctrl+d") == "",
    "AHK-symbol syntax should be required, not written modifier names")
Check(HotkeyRegistry.NormalizeSuffix("+^D") == "^+d",
    "modifiers should be canonicalised to ^!+# order and keys folded to lower case")
Check(HotkeyRegistry.NormalizeSuffix("CapsLock") == "",
    "CapsLock alone must not be assignable")
Check(HotkeyRegistry.NormalizeSuffix("") == "",
    "an empty suffix must be rejected")

; Editing a binding re-registers the live hotkey and updates the display.
Check(HotkeyRegistry.SetSuffix("killProcess", "+k"),
    "rebinding a shortcut to a free combination should succeed")
Check(HotkeyRegistry.GetSuffix("killProcess") == "+k",
    "the new binding should be readable after re-registration")
Check(HotkeyRegistry.GetDisplayKey("killProcess") == "CapsLock + Shift + K",
    "the display should follow the new binding")

; A combination used by another shortcut is rejected and leaves the previous
; binding intact.
Check(!HotkeyRegistry.SetSuffix("killProcess", "t"),
    "rebinding to a combination another shortcut already uses should fail")
Check(HotkeyRegistry.GetSuffix("killProcess") == "+k",
    "a rejected rebind must not change the stored binding")

; The file/desktop delete shortcut deliberately shares Shift+D with the text
; editing shortcut because their availability never overlaps.
Check(HotkeyRegistry.SetSuffix("deleteNextWord", "+d"),
    "Shift+D may be shared by the file-delete and delete-next-word shortcuts")

; Persistence round-trip keeps custom values.
saved := HotkeyRegistry.Serialize()
Check(InStr(saved, "killProcess=+k"), "serialized bindings should include the custom value")
Check(HotkeyRegistry.ResetDefaults(), "restoring defaults should succeed")
Check(HotkeyRegistry.GetSuffix("killProcess") == "k",
    "restoring defaults should return the original key")
Check(HotkeyRegistry.GetSuffix("fileDelete") == "+d",
    "restoring defaults should return the file-delete key")
restored := HotkeyRegistry.Deserialize(saved)
Check(restored["killProcess"] == "+k",
    "deserializing saved bindings should restore the custom value")

; Corrupt or conflicting persisted data falls back to a clean default set.
Check(HotkeyRegistry.Deserialize("killProcess=t").Count == 0,
    "a conflicting persisted payload should be rejected")
Check(HotkeyRegistry.Deserialize("unknownShortcut=x|killProcess=+k")["killProcess"] == "+k",
    "unknown ids should be ignored while known ids load")
Check(HotkeyRegistry.Deserialize("killProcess=CapsLock").Count == 0,
    "an unassignable persisted suffix should be rejected")

FileAppend("PASS: hotkey rebinding, conflict, persistence, and reset checks succeeded`n", "*")
ExitApp(0)
