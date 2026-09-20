#Requires AutoHotkey v2.0

class CloudSyncSerializer {
    static ExportConfig() {
        config := Map()

        cleanup := Map()
        cleanup["deleteMode"] := String(AppState.DeleteMode)
        cleanup["deleteDelay"] := String(AppState.DeleteDelay)
        cleanup["cleanupInterval"] := String(AppState.CleanupInterval)
        config["Cleanup"] := cleanup

        history := Map()
        history["maxHistory"] := String(AppState.MaxHistory)
        config["History"] := history

        general := Map()
        general["pasteMode"] := String(AppState.PasteMode)
        general["autoClean"] := AppState.AutoCleanEnabled ? "1" : "0"
        general["maxHistoryItems"] := String(AppState.MaxHistoryItems)
        general["language"] := String(AppState.CurrentLanguage)
        config["General"] := general

        imageMagick := Map()
        imageMagick["Path"] := String(AppState.ImageMagickExe)
        config["ImageMagick"] := imageMagick

        quickPhrase := Map()
        quickPhrase["enabled"] := AppState.QuickPhraseEnabled ? "1" : "0"
        config["QuickPhrase"] := quickPhrase

        pandoc := Map()
        pandoc["Path"] := String(AppState.PandocExe)
        pandoc["OutputFormat"] := String(AppState.PandocOutputFormat)
        config["Pandoc"] := pandoc

        windowHole := Map()
        windowHole["diameter"] := String(AppState.WindowHoleDiameter)
        windowHole["shape"] := String(AppState.WindowHoleShape)
        windowHole["activation"] := String(AppState.WindowHoleActivation)
        windowHole["updateInterval"] := String(AppState.WindowHoleUpdateInterval)
        windowHole["fallbackToMinimize"] := AppState.WindowHoleFallbackToMinimize ? "1" : "0"
        windowHole["allowedExecutables"] := Join(AppState.WindowHoleAllowedExecutables, "|")
        windowHole["excludedExecutables"] := Join(AppState.WindowHoleExcludedExecutables, "|")
        windowHole["allowedClasses"] := Join(AppState.WindowHoleAllowedClasses, "|")
        windowHole["excludedClasses"] := Join(AppState.WindowHoleExcludedClasses, "|")
        config["WindowHole"] := windowHole

        ignore := Map()
        ignore["Rules"] := Join(AppState.IgnorePatterns, "|")
        config["Ignore"] := ignore

        return config
    }

    static ExportQuickPhrases() {
        result := []

        for phrase in QuickPhraseStore.GetAll() {
            item := Map()
            item["id"] := phrase.id
            item["name"] := phrase.name
            item["category"] := phrase.category
            item["order"] := phrase.order
            item["contentFile"] := phrase.contentFile
            item["content"] := phrase.content
            result.Push(item)
        }

        return result
    }

    static ImportConfig(config) {
        if !IsObject(config) || !(config is Map)
            return false

        for sectionName, sectionData in config {
            if !(sectionData is Map)
                continue

            for key, value in sectionData {
                if !(value is String)
                    value := String(value)
                IniWrite(
                    value,
                    AppState.ConfigFile,
                    sectionName,
                    key
                )
            }
        }

        return true
    }
}
