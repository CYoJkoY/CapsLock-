#Requires AutoHotkey v2.0

class ConfigManager {
    static Load() {
        cfg := AppState.ConfigFile

        oldPath := A_ScriptDir "\ImageMagickPath.txt"
        if FileExist(oldPath) {
            try {
                legacy := FileRead(oldPath, "UTF-8")
                if legacy != ""
                    IniWrite(legacy, cfg, "ImageMagick", "Path")
                FileDelete(oldPath)
            }
        }

        if !FileExist(cfg)
            return

        try {
            AppState.DeleteMode        := IniRead(cfg, "Cleanup",   "deleteMode",      1)
            AppState.DeleteDelay       := IniRead(cfg, "Cleanup",   "deleteDelay",     10)
            AppState.CleanupInterval   := IniRead(cfg, "Cleanup",   "cleanupInterval", 30)
            AppState.ImageMagickExe    := IniRead(cfg, "ImageMagick", "Path",          "")
            AppState.MaxHistory        := IniRead(cfg, "History",   "maxHistory",     10000)
            AppState.PasteMode         := IniRead(cfg, "General",   "pasteMode",      1)
            AppState.AutoCleanEnabled  := IniRead(cfg, "General",   "autoClean",      "0") == "1"
            AppState.MaxHistoryItems   := Integer(IniRead(cfg, "General", "maxHistoryItems", "500"))
            AppState.QuickPhraseEnabled := IniRead(cfg, "QuickPhrase", "enabled", "1") == "1"
            AppState.PandocExe         := IniRead(cfg, "Pandoc", "Path", "")
            AppState.PandocOutputFormat := IniRead(cfg, "Pandoc", "OutputFormat", "docx")

            ; ---- Window Hole ----
            windowHoleDiameter := IniRead(cfg, "WindowHole", "diameter", "360")
            AppState.WindowHoleDiameter := IsNumber(windowHoleDiameter)
                ? Clamp(Integer(windowHoleDiameter), 80, 1200)
                : 360

            windowHoleShape := StrLower(Trim(IniRead(cfg, "WindowHole", "shape", "circle")))
            AppState.WindowHoleShape := (windowHoleShape == "circle" || windowHoleShape == "rounded" || windowHoleShape == "square")
                ? windowHoleShape
                : "circle"

            activation := StrLower(Trim(IniRead(cfg, "WindowHole", "activation", "hold")))
            AppState.WindowHoleActivation := (activation == "hold" || activation == "toggle")
                ? activation
                : "hold"

            updateInterval := IniRead(cfg, "WindowHole", "updateInterval", "30")
            AppState.WindowHoleUpdateInterval := IsNumber(updateInterval)
                ? Clamp(Integer(updateInterval), 15, 200)
                : 30

            AppState.WindowHoleSecondLevelEnabled := IniRead(cfg, "WindowHole", "secondLevel", "1") == "1"
            AppState.WindowHoleFallbackToMinimize := IniRead(cfg, "WindowHole", "fallbackToMinimize", "1") == "1"

            allowedExecutables := IniRead(cfg, "WindowHole", "allowedExecutables", "")
            excludedExecutables := IniRead(cfg, "WindowHole", "excludedExecutables", "")
            allowedClasses := IniRead(cfg, "WindowHole", "allowedClasses", "")
            excludedClasses := IniRead(cfg, "WindowHole", "excludedClasses", "")

            AppState.WindowHoleAllowedExecutables := allowedExecutables ? StrSplit(allowedExecutables, "|") : []
            AppState.WindowHoleExcludedExecutables := excludedExecutables ? StrSplit(excludedExecutables, "|") : []
            AppState.WindowHoleAllowedClasses := allowedClasses ? StrSplit(allowedClasses, "|") : []
            AppState.WindowHoleExcludedClasses := excludedClasses ? StrSplit(excludedClasses, "|") : []

            ; ---- Validate Pandoc output format ----
            ; If the loaded format is not a valid string or not in the supported list,
            ; reset to "docx" and update the config file immediately.
            if !_IsPandocFormatSupported(AppState.PandocOutputFormat) {
                AppState.PandocOutputFormat := "docx"
                IniWrite(AppState.PandocOutputFormat, cfg, "Pandoc", "OutputFormat")
            }
            ; -----------------------------------------

            langVal := IniRead(cfg, "General", "language", "")
            if langVal != "" && AppState.HasProp("CurrentLanguage")
                AppState.CurrentLanguage := langVal

            ignoreStr := IniRead(cfg, "Ignore", "Rules", "")
            AppState.IgnorePatterns := ignoreStr ? StrSplit(ignoreStr, "|") : []
        }
    }

    static Save() {
        cfg := AppState.ConfigFile
        try {
            IniWrite(AppState.DeleteMode,         cfg, "Cleanup",   "deleteMode")
            IniWrite(AppState.DeleteDelay,        cfg, "Cleanup",   "deleteDelay")
            IniWrite(AppState.CleanupInterval,    cfg, "Cleanup",   "cleanupInterval")
            IniWrite(AppState.MaxHistory,         cfg, "History",   "maxHistory")
            IniWrite(AppState.PasteMode,          cfg, "General",   "pasteMode")
            IniWrite(AppState.AutoCleanEnabled ? "1" : "0", cfg, "General", "autoClean")
            IniWrite(AppState.MaxHistoryItems,    cfg, "General",   "maxHistoryItems")
            IniWrite(AppState.QuickPhraseEnabled ? "1" : "0", cfg, "QuickPhrase", "enabled")
            IniWrite(AppState.PandocExe,          cfg, "Pandoc", "Path")
            IniWrite(AppState.PandocOutputFormat, cfg, "Pandoc", "OutputFormat")

            ; ---- Window Hole ----
            IniWrite(AppState.WindowHoleDiameter, cfg, "WindowHole", "diameter")
            IniWrite(AppState.WindowHoleShape, cfg, "WindowHole", "shape")
            IniWrite(AppState.WindowHoleActivation, cfg, "WindowHole", "activation")
            IniWrite(AppState.WindowHoleUpdateInterval, cfg, "WindowHole", "updateInterval")
            IniWrite(AppState.WindowHoleSecondLevelEnabled ? "1" : "0", cfg, "WindowHole", "secondLevel")
            IniWrite(AppState.WindowHoleFallbackToMinimize ? "1" : "0", cfg, "WindowHole", "fallbackToMinimize")
            IniWrite(Join(AppState.WindowHoleAllowedExecutables, "|"), cfg, "WindowHole", "allowedExecutables")
            IniWrite(Join(AppState.WindowHoleExcludedExecutables, "|"), cfg, "WindowHole", "excludedExecutables")
            IniWrite(Join(AppState.WindowHoleAllowedClasses, "|"), cfg, "WindowHole", "allowedClasses")
            IniWrite(Join(AppState.WindowHoleExcludedClasses, "|"), cfg, "WindowHole", "excludedClasses")

            if AppState.HasProp("CurrentLanguage") && AppState.CurrentLanguage != ""
                IniWrite(AppState.CurrentLanguage, cfg, "General", "language")

            ignoreStr := Join(AppState.IgnorePatterns, "|")
            IniWrite(ignoreStr, cfg, "Ignore", "Rules")
        }
    }
}

; Helper function to check if a format is a valid string and exists in the supported list.
; This function is defined here to avoid dependency on Pandoc.ahk.
_IsPandocFormatSupported(format) {
    ; Ensure format is a non-empty string
    if !(format is String) || format == ""
        return false
    for f in AppState.PandocOutputFormats {
        if (f == format)
            return true
    }
    return false
}
