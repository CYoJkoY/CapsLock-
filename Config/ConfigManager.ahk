#Requires AutoHotkey v2.0

class ConfigManager {
    static Load() {
        cfg := AppState.ConfigFile
        oldPath := A_ScriptDir "\ImageMagickPath.txt"
        if FileExist( oldPath ) {
            try {
                legacy := FileRead( oldPath, "UTF-8" )
                if legacy != ""
                    IniWrite( legacy, cfg, "ImageMagick", "Path" )
                FileDelete( oldPath )
            }
        }

        if !FileExist( cfg )
            return

        try {
            AppState.DeleteMode := IniRead( cfg, "Cleanup", "deleteMode", 1 )
            AppState.DeleteDelay := IniRead( cfg, "Cleanup", "deleteDelay", 10 )
            AppState.CleanupInterval := IniRead( cfg, "Cleanup", "cleanupInterval", 30 )
            AppState.ImageMagickExe := IniRead( cfg, "ImageMagick", "Path", "" )
            AppState.MaxHistory := IniRead( cfg, "History", "maxHistory", 10000 )
            AppState.PasteMode := IniRead( cfg, "General", "pasteMode", 1 )
            ignoreStr := IniRead( cfg, "Ignore", "Rules", "" )

            if ignoreStr != "" {
                AppState.IgnorePatterns := StrSplit( ignoreStr, "`n", "`r" )
            } else {
                AppState.IgnorePatterns := []
            }

        } catch {
        }
    }

    static Save() {
        cfg := AppState.ConfigFile
        try {
            IniWrite( AppState.DeleteMode, cfg, "Cleanup", "deleteMode" )
            IniWrite( AppState.DeleteDelay, cfg, "Cleanup", "deleteDelay" )
            IniWrite( AppState.CleanupInterval, cfg, "Cleanup", "cleanupInterval" )
            IniWrite( AppState.MaxHistory, cfg, "History", "maxHistory" )
            IniWrite( AppState.PasteMode, cfg, "General", "pasteMode" )

            ignoreStr := ""
            for pattern in AppState.IgnorePatterns
                ignoreStr .= pattern "`n"
            ignoreStr := RTrim( ignoreStr, "`n" )

            IniWrite( ignoreStr, cfg, "Ignore", "Rules" )

        } catch {
        }
    }
}
