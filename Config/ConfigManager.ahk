#Requires AutoHotkey v2.0

class ConfigManager {
    static Load() {
        SecureIni.Open(AppState.ConfigFile)
        AppState.DeleteMode         := SecureIni.Get("Cleanup", "deleteMode", 1)
        AppState.DeleteDelay        := SecureIni.Get("Cleanup", "deleteDelay", 10)
        AppState.CleanupInterval    := SecureIni.Get("Cleanup", "cleanupInterval", 30)
        AppState.ImageMagickExe     := SecureIni.Get("ImageMagick", "Path", "")
        AppState.MaxHistory         := SecureIni.Get("History", "maxHistory", 10000)
        AppState.PasteMode          := SecureIni.Get("General", "pasteMode", 1)
        AppState.AutoCleanEnabled   := SecureIni.Get("General", "autoClean", "0") == "1"
        AppState.MaxHistoryItems    := Integer(SecureIni.Get("General", "maxHistoryItems", "500"))
        AppState.PandocExe          := SecureIni.Get("Pandoc", "Path", "")
        AppState.PandocOutputFormat := SecureIni.Get("Pandoc", "OutputFormat", "docx")
        if !_IsPandocFormatSupported(AppState.PandocOutputFormat) {
            AppState.PandocOutputFormat := "docx"
            SecureIni.Set("Pandoc", "OutputFormat", "docx")
        }
        langVal := SecureIni.Get("General", "language", "")
        if langVal != "" && AppState.HasProp("CurrentLanguage")
            AppState.CurrentLanguage := langVal
        ignoreStr := SecureIni.Get("Ignore", "Rules", "")
        AppState.IgnorePatterns := ignoreStr ? StrSplit(ignoreStr, "|") : []
        AppState.ApiUrl         := SecureIni.Get("AI", "ApiUrl", "")
        AppState.ApiKey         := SecureIni.Get("AI", "ApiKey", "")
        AppState.ApiModel       := SecureIni.Get("AI", "ApiModel", "gpt-3.5-turbo")
        AppState.ApiMaxTokens   := Integer(SecureIni.Get("AI", "ApiMaxTokens", "2000"))
        try AppState.ApiTemperature := Float(SecureIni.Get("AI", "ApiTemperature", "0.7"))
        catch 
            AppState.ApiTemperature := 0.7
        AppState.ApiStreamMode := SecureIni.Get("AI", "StreamMode", "0") == "1"
        AppState.GistToken := SecureIni.Get("Gist", "Token", "")
        AppState.GistId    := SecureIni.Get("Gist", "GistId", "")
        if SecureIni.WasLegacy()
            SecureIni.Save()
    }

    static Save() {
        SecureIni.Set("Cleanup", "deleteMode",      AppState.DeleteMode)
        SecureIni.Set("Cleanup", "deleteDelay",     AppState.DeleteDelay)
        SecureIni.Set("Cleanup", "cleanupInterval", AppState.CleanupInterval)
        SecureIni.Set("History", "maxHistory",      AppState.MaxHistory)
        SecureIni.Set("General", "pasteMode",       AppState.PasteMode)
        SecureIni.Set("General", "autoClean",       AppState.AutoCleanEnabled ? "1" : "0")
        SecureIni.Set("General", "maxHistoryItems", AppState.MaxHistoryItems)
        SecureIni.Set("Pandoc", "Path",         AppState.PandocExe)
        SecureIni.Set("Pandoc", "OutputFormat", AppState.PandocOutputFormat)
        if AppState.HasProp("CurrentLanguage") && AppState.CurrentLanguage != ""
            SecureIni.Set("General", "language", AppState.CurrentLanguage)
        SecureIni.Set("Ignore", "Rules", Join(AppState.IgnorePatterns, "|"))
        SecureIni.Set("AI", "ApiUrl",         AppState.ApiUrl)
        SecureIni.Set("AI", "ApiKey",         AppState.ApiKey)
        SecureIni.Set("AI", "ApiModel",       AppState.ApiModel)
        SecureIni.Set("AI", "ApiMaxTokens",   AppState.ApiMaxTokens)
        SecureIni.Set("AI", "ApiTemperature", AppState.ApiTemperature)
        SecureIni.Set("AI", "StreamMode",     AppState.ApiStreamMode ? "1" : "0")
        SecureIni.Set("Gist", "Token", AppState.GistToken)
        SecureIni.Set("Gist", "GistId", AppState.GistId)
        SecureIni.Save()
    }
}

; Validates whether the format is a valid string
; and exists in the supported list
; (independent of Pandoc.ahk).
_IsPandocFormatSupported(format) {
    if !(format is String) || format == ""
        return false
    for f in AppState.PandocOutputFormats
        if (f == format)
            return true
    return false
}
