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

        AppState.DeleteMode := IniRead(cfg, "Cleanup", "deleteMode", 1)
        AppState.DeleteDelay := IniRead(cfg, "Cleanup", "deleteDelay", 10)
        AppState.CleanupInterval := IniRead(cfg, "Cleanup", "cleanupInterval", 30)
        AppState.ImageMagickExe := IniRead(cfg, "ImageMagick", "Path", "")
        AppState.MaxHistory := IniRead(cfg, "History", "maxHistory", 10000)
        AppState.PasteMode := IniRead(cfg, "General", "pasteMode", 1)
        AppState.AutoCleanEnabled := IniRead(cfg, "General", "autoClean", "0") == "1"
        AppState.MaxHistoryItems := Integer(IniRead(cfg, "General", "maxHistoryItems", "500"))
        AppState.QuickPhraseEnabled := IniRead(cfg, "QuickPhrase", "enabled", "1") == "1"
        AppState.ThemeMode := StrLower(Trim(IniRead(cfg, "UI", "theme", "dark")))
        AppState.PandocExe := IniRead(cfg, "Pandoc", "Path", "")
        AppState.PandocOutputFormat := IniRead(cfg, "Pandoc", "OutputFormat", "docx")
        ; ---- Cloud Sync ----
        AppState.CloudSyncEnabled :=
            IniRead(cfg, "CloudSync", "enabled", "0") == "1"

        AppState.CloudSyncProvider :=
            StrLower(
                Trim(
                    IniRead(cfg, "CloudSync", "provider", "gist")
                )
            )

        AppState.CloudSyncTarget :=
            Trim(
                IniRead(cfg, "CloudSync", "target", "")
            )

        AppState.CloudSyncAutoEnabled :=
            IniRead(cfg, "CloudSync", "autoSync", "0") == "1"

        intervalText := IniRead(cfg, "CloudSync", "interval", "30")
        AppState.CloudSyncInterval :=
            IsNumber(intervalText)
                ? Clamp(Integer(intervalText), 5, 1440)
                : 30

        AppState.CloudSyncEncryptionEnabled :=
            IniRead(cfg, "CloudSync", "encryption", "0") == "1"

        AppState.CloudSyncDeviceName :=
            Trim(
                IniRead(cfg, "CloudSync", "deviceName", "")
            )

        AppState.CloudSyncGitHubOwner :=
            Trim(IniRead(cfg, "CloudSyncGitHub", "owner", ""))
        AppState.CloudSyncGitHubRepository :=
            Trim(IniRead(cfg, "CloudSyncGitHub", "repository", ""))
        AppState.CloudSyncGitHubBranch :=
            Trim(IniRead(cfg, "CloudSyncGitHub", "branch", "main"))
        AppState.CloudSyncGitHubPath :=
            Trim(IniRead(cfg, "CloudSyncGitHub", "path", "CapsLockSync/capslock-sync.json"))

        AppState.CloudSyncWebDavUrl :=
            Trim(IniRead(cfg, "CloudSyncWebDAV", "url", ""))
        AppState.CloudSyncWebDavPath :=
            Trim(IniRead(cfg, "CloudSyncWebDAV", "path", "capslock-sync.json"))

        AppState.CloudSyncGoogleClientId :=
            Trim(IniRead(cfg, "CloudSyncGoogle", "clientId", ""))

        AppState.CloudSyncOneDriveClientId :=
            Trim(IniRead(cfg, "CloudSyncOneDrive", "clientId", ""))
        AppState.CloudSyncOneDriveTenant :=
            Trim(IniRead(cfg, "CloudSyncOneDrive", "tenant", "common"))
        AppState.CloudSyncOneDrivePath :=
            Trim(IniRead(cfg, "CloudSyncOneDrive", "path", "CapsLock-/capslock-sync.json"))

        ; ---- Window Hole ----
        windowHoleDiameter := IniRead(cfg, "WindowHole", "diameter", "360")
        AppState.WindowHoleDiameter := IsNumber(windowHoleDiameter)
            ? Clamp(Integer(windowHoleDiameter), 80, 1200)
            : 360

        windowHoleShape := StrLower(Trim(IniRead(cfg, "WindowHole", "shape", "circle")))
        AppState.WindowHoleShape := (windowHoleShape == "circle" || windowHoleShape == "rounded" || windowHoleShape ==
            "square")
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

        AppState.WindowHoleFallbackToMinimize := IniRead(cfg, "WindowHole", "fallbackToMinimize", "1") == "1"

        allowedExecutables := IniRead(cfg, "WindowHole", "allowedExecutables", "")
        excludedExecutables := IniRead(cfg, "WindowHole", "excludedExecutables", "")
        allowedClasses := IniRead(cfg, "WindowHole", "allowedClasses", "")
        excludedClasses := IniRead(cfg, "WindowHole", "excludedClasses", "")

        AppState.WindowHoleAllowedExecutables := allowedExecutables ? StrSplit(allowedExecutables, "|") : []
        AppState.WindowHoleExcludedExecutables := excludedExecutables ? StrSplit(excludedExecutables, "|") : []
        AppState.WindowHoleAllowedClasses := allowedClasses ? StrSplit(allowedClasses, "|") : []
        AppState.WindowHoleExcludedClasses := excludedClasses ? StrSplit(excludedClasses, "|") : []

        ; ---- Always-on-top indicator ----
        AppState.AlwaysOnTopIndicator :=
            IniRead(cfg, "Window", "topmostIndicator", "1") == "1"

        ; ---- Spotlight ----
        AppState.SpotlightRadius := Clamp(
            IsNumber(IniRead(cfg, "Spotlight", "radius", "180"))
                ? Integer(IniRead(cfg, "Spotlight", "radius", "180")) : 180,
            40, 900
        )

        AppState.SpotlightSoftness := Clamp(
            IsNumber(IniRead(cfg, "Spotlight", "softness", "60"))
                ? Integer(IniRead(cfg, "Spotlight", "softness", "60")) : 60,
            0, 250
        )

        AppState.SpotlightDarkness := Clamp(
            IsNumber(IniRead(cfg, "Spotlight", "darkness", "55"))
                ? Integer(IniRead(cfg, "Spotlight", "darkness", "55")) : 55,
            5, 95
        )

        spotlightShape := StrLower(Trim(IniRead(cfg, "Spotlight", "shape", "circle")))
        AppState.SpotlightShape := _IsAllowedValue(spotlightShape, AppState.SpotlightShapes)
            ? spotlightShape : "circle"

        spotlightActivation := StrLower(Trim(IniRead(cfg, "Spotlight", "activation", "toggle")))
        AppState.SpotlightActivation := _IsAllowedValue(spotlightActivation, AppState.SpotlightActivations)
            ? spotlightActivation : "toggle"

        AppState.SpotlightUpdateInterval := Clamp(
            IsNumber(IniRead(cfg, "Spotlight", "updateInterval", "16"))
                ? Integer(IniRead(cfg, "Spotlight", "updateInterval", "16")) : 16,
            8, 100
        )

        ; ---- Dynamic Zoom ----
        AppState.ZoomFactor := Clamp(
            IsNumber(IniRead(cfg, "Zoom", "factor", "3"))
                ? Integer(IniRead(cfg, "Zoom", "factor", "3")) : 3,
            2, 16
        )

        zoomActivation := StrLower(Trim(IniRead(cfg, "Zoom", "activation", "toggle")))
        AppState.ZoomActivation := _IsAllowedValue(zoomActivation, AppState.ZoomActivations)
            ? zoomActivation : "toggle"

        AppState.ZoomUpdateInterval := Clamp(
            IsNumber(IniRead(cfg, "Zoom", "updateInterval", "16"))
                ? Integer(IniRead(cfg, "Zoom", "updateInterval", "16")) : 16,
            8, 100
        )

        ; ---- Window Switcher ----
        AppState.WindowSwitcherShowIcons :=
            IniRead(cfg, "WindowSwitcher", "showIcons", "1") == "1"

        iconSizeText := IniRead(cfg, "WindowSwitcher", "iconSize", "24")
        AppState.WindowSwitcherIconSize := IsNumber(iconSizeText)
            ? _ClampToAllowed(Integer(iconSizeText), AppState.WindowSwitcherIconSizes, 24)
            : 24

        density := StrLower(Trim(IniRead(cfg, "WindowSwitcher", "density", "normal")))
        AppState.WindowSwitcherDensity := _IsAllowedValue(
            density,
            AppState.WindowSwitcherDensities
        ) ? density : "normal"

        AppState.WindowSwitcherShowProcess :=
            IniRead(cfg, "WindowSwitcher", "showProcess", "1") == "1"

        AppState.WindowSwitcherHighlightRow :=
            IniRead(cfg, "WindowSwitcher", "highlightRow", "1") == "1"

        if !_IsPandocFormatSupported(AppState.PandocOutputFormat) {
            AppState.PandocOutputFormat := "docx"
            IniWrite(AppState.PandocOutputFormat, cfg, "Pandoc", "OutputFormat")
        }

        langVal := IniRead(cfg, "General", "language", "")
        if langVal != ""
            AppState.CurrentLanguage := langVal

        ignoreStr := IniRead(cfg, "Ignore", "Rules", "")
        AppState.IgnorePatterns := ignoreStr ? StrSplit(ignoreStr, "|") : []

    }

    static Save(markCloudSyncDirty := true) {
        cfg := AppState.ConfigFile

        IniWrite(AppState.DeleteMode, cfg, "Cleanup", "deleteMode")
        IniWrite(AppState.DeleteDelay, cfg, "Cleanup", "deleteDelay")
        IniWrite(AppState.CleanupInterval, cfg, "Cleanup", "cleanupInterval")
        IniWrite(AppState.MaxHistory, cfg, "History", "maxHistory")
        IniWrite(AppState.PasteMode, cfg, "General", "pasteMode")
        IniWrite(AppState.AutoCleanEnabled ? "1" : "0", cfg, "General", "autoClean")
        IniWrite(AppState.MaxHistoryItems, cfg, "General", "maxHistoryItems")
        IniWrite(AppState.QuickPhraseEnabled ? "1" : "0", cfg, "QuickPhrase", "enabled")
        IniWrite(AppState.ThemeMode, cfg, "UI", "theme")
        IniWrite(AppState.PandocExe, cfg, "Pandoc", "Path")
        IniWrite(AppState.PandocOutputFormat, cfg, "Pandoc", "OutputFormat")
        IniWrite(AppState.ImageMagickExe, cfg, "ImageMagick", "Path")

        ; ---- Window Hole ----
        IniWrite(AppState.WindowHoleDiameter, cfg, "WindowHole", "diameter")
        IniWrite(AppState.WindowHoleShape, cfg, "WindowHole", "shape")
        IniWrite(AppState.WindowHoleActivation, cfg, "WindowHole", "activation")
        IniWrite(AppState.WindowHoleUpdateInterval, cfg, "WindowHole", "updateInterval")
        IniWrite(AppState.WindowHoleFallbackToMinimize ? "1" : "0", cfg, "WindowHole", "fallbackToMinimize")
        IniWrite(Join(AppState.WindowHoleAllowedExecutables, "|"), cfg, "WindowHole", "allowedExecutables")
        IniWrite(Join(AppState.WindowHoleExcludedExecutables, "|"), cfg, "WindowHole", "excludedExecutables")
        IniWrite(Join(AppState.WindowHoleAllowedClasses, "|"), cfg, "WindowHole", "allowedClasses")
        IniWrite(Join(AppState.WindowHoleExcludedClasses, "|"), cfg, "WindowHole", "excludedClasses")

        if AppState.CurrentLanguage != ""
            IniWrite(AppState.CurrentLanguage, cfg, "General", "language")

        ignoreStr := Join(AppState.IgnorePatterns, "|")
        IniWrite(ignoreStr, cfg, "Ignore", "Rules")

        ; ---- Always-on-top indicator ----
        IniWrite(AppState.AlwaysOnTopIndicator ? "1" : "0", cfg, "Window", "topmostIndicator")

        ; ---- Spotlight ----
        IniWrite(AppState.SpotlightRadius, cfg, "Spotlight", "radius")
        IniWrite(AppState.SpotlightSoftness, cfg, "Spotlight", "softness")
        IniWrite(AppState.SpotlightDarkness, cfg, "Spotlight", "darkness")
        IniWrite(AppState.SpotlightShape, cfg, "Spotlight", "shape")
        IniWrite(AppState.SpotlightActivation, cfg, "Spotlight", "activation")
        IniWrite(AppState.SpotlightUpdateInterval, cfg, "Spotlight", "updateInterval")

        ; ---- Dynamic Zoom ----
        IniWrite(AppState.ZoomFactor, cfg, "Zoom", "factor")
        IniWrite(AppState.ZoomActivation, cfg, "Zoom", "activation")
        IniWrite(AppState.ZoomUpdateInterval, cfg, "Zoom", "updateInterval")

        ; ---- Window Switcher ----
        IniWrite(AppState.WindowSwitcherShowIcons ? "1" : "0", cfg, "WindowSwitcher", "showIcons")
        IniWrite(AppState.WindowSwitcherIconSize, cfg, "WindowSwitcher", "iconSize")
        IniWrite(AppState.WindowSwitcherDensity, cfg, "WindowSwitcher", "density")
        IniWrite(AppState.WindowSwitcherShowProcess ? "1" : "0", cfg, "WindowSwitcher", "showProcess")
        IniWrite(AppState.WindowSwitcherHighlightRow ? "1" : "0", cfg, "WindowSwitcher", "highlightRow")

        ; ---- Cloud Sync ----
        IniWrite(AppState.CloudSyncEnabled ? "1" : "0", cfg, "CloudSync", "enabled")
        IniWrite(AppState.CloudSyncProvider, cfg, "CloudSync", "provider")
        IniWrite(AppState.CloudSyncTarget, cfg, "CloudSync", "target")
        IniWrite(AppState.CloudSyncAutoEnabled ? "1" : "0", cfg, "CloudSync", "autoSync")
        IniWrite(AppState.CloudSyncInterval, cfg, "CloudSync", "interval")
        IniWrite(AppState.CloudSyncEncryptionEnabled ? "1" : "0", cfg, "CloudSync", "encryption")
        IniWrite(AppState.CloudSyncDeviceName, cfg, "CloudSync", "deviceName")

        IniWrite(AppState.CloudSyncGitHubOwner, cfg, "CloudSyncGitHub", "owner")
        IniWrite(AppState.CloudSyncGitHubRepository, cfg, "CloudSyncGitHub", "repository")
        IniWrite(AppState.CloudSyncGitHubBranch, cfg, "CloudSyncGitHub", "branch")
        IniWrite(AppState.CloudSyncGitHubPath, cfg, "CloudSyncGitHub", "path")

        IniWrite(AppState.CloudSyncWebDavUrl, cfg, "CloudSyncWebDAV", "url")
        IniWrite(AppState.CloudSyncWebDavPath, cfg, "CloudSyncWebDAV", "path")

        IniWrite(AppState.CloudSyncGoogleClientId, cfg, "CloudSyncGoogle", "clientId")

        IniWrite(AppState.CloudSyncOneDriveClientId, cfg, "CloudSyncOneDrive", "clientId")
        IniWrite(AppState.CloudSyncOneDriveTenant, cfg, "CloudSyncOneDrive", "tenant")
        IniWrite(AppState.CloudSyncOneDrivePath, cfg, "CloudSyncOneDrive", "path")

        if markCloudSyncDirty && !AppState.CloudSyncApplying
            CloudSyncCoordinator.MarkLocalChanged()
    }
}

_IsAllowedValue(value, allowed) {
    for candidate in allowed {
        if candidate == value
            return true
    }
    return false
}

; Keeps numeric settings on one of the offered values, falling back to the
; default when the stored value is out of range or was edited by hand.
_ClampToAllowed(value, allowed, defaultValue) {
    if _IsAllowedValue(value, allowed)
        return value

    nearest := defaultValue
    bestDistance := 0
    found := false

    for candidate in allowed {
        distance := Abs(candidate - value)
        if !found || distance < bestDistance {
            nearest := candidate
            bestDistance := distance
            found := true
        }
    }

    return nearest
}

_IsPandocFormatSupported(format) {
    if !(format is String) || format == ""
        return false
    for f in AppState.PandocOutputFormats {
        if (f == format)
            return true
    }
    return false
}
