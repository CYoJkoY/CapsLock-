#Requires AutoHotkey v2.0

class ConfigManager {
    static Load() {
        cfg := AppState.ConfigFile

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
            AppState.PandocExe         := IniRead(cfg, "Pandoc", "Path", "")
            AppState.PandocOutputFormat := IniRead(cfg, "Pandoc", "OutputFormat", "docx")

            ; ---- Validate Pandoc output format ----
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

            ; ---- AI API Settings ----
            AppState.ApiUrl         := IniRead(cfg, "AI", "ApiUrl",      "")
            AppState.ApiKey         := IniRead(cfg, "AI", "ApiKey",      "")
            AppState.ApiModel       := IniRead(cfg, "AI", "ApiModel",    "gpt-3.5-turbo")
            AppState.ApiMaxTokens   := Integer(IniRead(cfg, "AI", "ApiMaxTokens", "2000"))
            try AppState.ApiTemperature := Float(IniRead(cfg, "AI", "ApiTemperature", "0.7"))
            catch
                AppState.ApiTemperature := 0.7
            AppState.ApiStreamMode := IniRead(cfg, "AI", "StreamMode", "0") == "1"
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
            IniWrite(AppState.PandocExe,          cfg, "Pandoc", "Path")
            IniWrite(AppState.PandocOutputFormat, cfg, "Pandoc", "OutputFormat")

            if AppState.HasProp("CurrentLanguage") && AppState.CurrentLanguage != ""
                IniWrite(AppState.CurrentLanguage, cfg, "General", "language")

            ignoreStr := Join(AppState.IgnorePatterns, "|")
            IniWrite(ignoreStr, cfg, "Ignore", "Rules")

            ; ---- AI API Settings ----
            IniWrite(AppState.ApiUrl,         cfg, "AI", "ApiUrl")
            IniWrite(AppState.ApiKey,         cfg, "AI", "ApiKey")
            IniWrite(AppState.ApiModel,       cfg, "AI", "ApiModel")
            IniWrite(AppState.ApiMaxTokens,   cfg, "AI", "ApiMaxTokens")
            IniWrite(AppState.ApiTemperature, cfg, "AI", "ApiTemperature")
            IniWrite(AppState.ApiStreamMode ? "1" : "0", cfg, "AI", "StreamMode")
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
