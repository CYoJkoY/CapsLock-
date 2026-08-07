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
            AppState.PandocExe          := IniRead(cfg, "Pandoc", "Path", "")
            AppState.PandocOutputFormat := IniRead(cfg, "Pandoc", "OutputFormat", "docx")

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
            IniWrite(AppState.PandocExe,          cfg, "Pandoc", "Path")
            IniWrite(AppState.PandocOutputFormat, cfg, "Pandoc", "OutputFormat")

            if AppState.HasProp("CurrentLanguage") && AppState.CurrentLanguage != ""
                IniWrite(AppState.CurrentLanguage, cfg, "General", "language")

            ignoreStr := Join(AppState.IgnorePatterns, "|")
            IniWrite(ignoreStr, cfg, "Ignore", "Rules")
        }
    }
}
