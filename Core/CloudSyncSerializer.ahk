#Requires AutoHotkey v2.0

class CloudSyncSerializer {
    ; Machine-specific settings: they depend on local install paths / installed
    ; software, so syncing them would overwrite the peer's working values.
    ; These keys are excluded from the sync payload; the peer keeps its own
    ; local values when applying.
    static MachineLocal := Map(
        "ImageMagick", Map("Path", true),
        "Pandoc",      Map("Path", true),
        "WindowHole",  Map(
            "allowedExecutables",  true,
            "excludedExecutables", true,
            "allowedClasses",      true,
            "excludedClasses",     true
        )
    )

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

        mywindowHole := Map()
        mywindowHole["diameter"] := String(AppState.WindowHoleDiameter)
        mywindowHole["shape"] := String(AppState.WindowHoleShape)
        mywindowHole["activation"] := String(AppState.WindowHoleActivation)
        mywindowHole["updateInterval"] := String(AppState.WindowHoleUpdateInterval)
        mywindowHole["fallbackToMinimize"] := AppState.WindowHoleFallbackToMinimize ? "1" : "0"
        mywindowHole["allowedExecutables"] := Join(AppState.WindowHoleAllowedExecutables, "|")
        mywindowHole["excludedExecutables"] := Join(AppState.WindowHoleExcludedExecutables, "|")
        mywindowHole["allowedClasses"] := Join(AppState.WindowHoleAllowedClasses, "|")
        mywindowHole["excludedClasses"] := Join(AppState.WindowHoleExcludedClasses, "|")
        config["WindowHole"] := mywindowHole

        ignore := Map()
        ignore["Rules"] := Join(AppState.IgnorePatterns, "|")
        config["Ignore"] := ignore

        return this._StripMachineLocal(config)
    }

    static _StripMachineLocal(config) {
        if !IsObject(config) || !(config is Map)
            return config

        for sectionName, keys in this.MachineLocal {
            if !config.Has(sectionName) || !(config[sectionName] is Map)
                continue
            for key in keys {
                if config[sectionName].Has(key)
                    config[sectionName].Delete(key)
            }
        }

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
