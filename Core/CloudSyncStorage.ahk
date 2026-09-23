#Requires AutoHotkey v2.0

class CloudSyncStorage {
    static ApplyPackage(package) {
        if !CloudSyncModel.VerifyPackage(package)
            return false

        stagingDir := AppState.CloudSyncDir "\staging\apply-"
            CloudSyncModel.CreateRevisionId()

        backupDir := ""
        AppState.CloudSyncApplying := true

        try {
            if !this._BuildStaging(package, stagingDir)
                return false

            backupDir := this.BackupCurrentState()
            if backupDir == ""
                return false

            CloudSyncState.Set("Sync", "applyInProgress", "1")
            CloudSyncState.Set("Sync", "backupPath", backupDir)

            if !this._ApplyConfig(package["payload"]["config"])
                throw Error("Configuration apply failed.")

            if !this._ReplaceQuickPhrases(stagingDir)
                throw Error("Quick Phrase apply failed.")

            CloudSyncState.Set("Sync", "applyInProgress", "0")
            CloudSyncState.Set("Sync", "backupPath", "")

            try DirDelete(stagingDir, true)
            catch {
            }

            return true
        } catch {
            this._RestoreBackup(backupDir)

            CloudSyncState.Set("Sync", "applyInProgress", "0")
            CloudSyncState.Set("Sync", "backupPath", "")

            try DirDelete(stagingDir, true)
            catch {
            }

            return false
        } finally {
            AppState.CloudSyncApplying := false
        }
    }

    static BackupCurrentState() {
        timestamp := CloudSyncModel.CreateRevisionId()
        backupDir := AppState.CloudSyncBackupDir "\" timestamp

        if !DirExist(backupDir)
            DirCreate(backupDir)

        try {
            if FileExist(AppState.ConfigFile)
                FileCopy(AppState.ConfigFile, backupDir "\Config.ini", true)

            if FileExist(AppState.QuickPhraseFile)
                FileCopy(AppState.QuickPhraseFile, backupDir "\QuickPhrases.ini", true)

            if DirExist(AppState.QuickPhraseContentDir)
                DirCopy(
                    AppState.QuickPhraseContentDir,
                    backupDir "\QuickPhrases",
                    true
                )

            marker := backupDir "\complete.marker"
            FileAppend("complete", marker, "UTF-8")

            return backupDir
        } catch {
            try DirDelete(backupDir, true)
            catch {
            }
            return ""
        }
    }

    static RecoverInterruptedApply() {
        backupDir := CloudSyncState.Get("Sync", "backupPath", "")
        if backupDir == ""
            return false

        ok := this._RestoreBackup(backupDir)
        if ok {
            CloudSyncState.Set("Sync", "applyInProgress", "0")
            CloudSyncState.Set("Sync", "backupPath", "")
        } else {
            CloudSyncState.Set("Sync", "state", "recovery-error")
        }
        return ok
    }

    static _BuildStaging(package, stagingDir) {
        if DirExist(stagingDir)
            try DirDelete(stagingDir, true)

        DirCreate(stagingDir)
        DirCreate(stagingDir "\QuickPhrases")

        configPath := stagingDir "\Config.ini"
        if !this._WriteStagedConfig(package["payload"]["config"], configPath)
            return false

        qpPath := stagingDir "\QuickPhrases.ini"

        for phrase in package["payload"]["quickPhrases"] {
            if !IsObject(phrase) || !(phrase is Map)
                return false

            if !phrase.Has("id") || !phrase.Has("name")
                return false

            id := Integer(phrase["id"])
            if id <= 0
                return false

            name := String(phrase["name"])
            category := phrase.Has("category") ? String(phrase["category"]) : ""
            order := phrase.Has("order") ? Integer(phrase["order"]) : id
            content := phrase.Has("content") ? String(phrase["content"]) : ""

            if name == "" || content == ""
                return false

            contentFile := "phrase-" id ".txt"
            contentPath := stagingDir "\QuickPhrases\" contentFile

            mtfile := FileOpen(contentPath, "w", "UTF-8")
            if !IsObject(mtfile)
                return false
            try {
                mtfile.Write(content)
                mtfile.Close()
            } catch {
                try mtfile.Close()
                return false
            }

            IniWrite(name, qpPath, "QuickPhrase_" id, "Name")
            IniWrite(category, qpPath, "QuickPhrase_" id, "Category")
            IniWrite(order, qpPath, "QuickPhrase_" id, "Order")
            IniWrite(contentFile, qpPath, "QuickPhrase_" id, "ContentFile")
        }

        return true
    }

    static _WriteStagedConfig(config, path) {
        if !IsObject(config) || !(config is Map)
            return false

        try {
            for sectionName, sectionData in config {
                if !(sectionData is Map)
                    continue

                for key, value in sectionData {
                    IniWrite(
                        String(value),
                        path,
                        sectionName,
                        key
                    )
                }
            }
            return true
        } catch {
            return false
        }
    }

    static _ApplyConfig(config) {
        if !IsObject(config) || !(config is Map)
            return false

        try {
            for sectionName, sectionData in config {
                if !(sectionData is Map)
                    continue

                for key, value in sectionData {
                    IniWrite(
                        String(value),
                        AppState.ConfigFile,
                        sectionName,
                        key
                    )
                }
            }

            ConfigManager.Load()
            return true
        } catch {
            return false
        }
    }

    static _ReplaceQuickPhrases(stagingDir) {
        qpPath := stagingDir "\QuickPhrases.ini"
        if !FileExist(qpPath)
            return false

        try {
            if FileExist(AppState.QuickPhraseFile)
                FileDelete(AppState.QuickPhraseFile)

            FileCopy(qpPath, AppState.QuickPhraseFile, true)

            if DirExist(AppState.QuickPhraseContentDir)
                DirDelete(AppState.QuickPhraseContentDir, true)

            DirCreate(AppState.QuickPhraseContentDir)

            sourceDir := stagingDir "\QuickPhrases"
            if DirExist(sourceDir) {
                Loop Files, sourceDir "\phrase-*.txt", "F"
                    FileCopy(A_LoopFileFullPath, AppState.QuickPhraseContentDir "\" A_LoopFileName, true)
            }

            QuickPhraseStore.Load()
            return true
        } catch {
            return false
        }
    }

    static _RestoreBackup(backupDir) {
        if backupDir == "" || !DirExist(backupDir)
            return false

        marker := backupDir "\complete.marker"
        if !FileExist(marker)
            return false

        ok := true

        try {
            if FileExist(backupDir "\Config.ini")
                FileCopy(backupDir "\Config.ini", AppState.ConfigFile, true)
            else if FileExist(AppState.ConfigFile)
                FileDelete(AppState.ConfigFile)
        } catch {
            ok := false
        }

        try {
            if FileExist(backupDir "\QuickPhrases.ini")
                FileCopy(backupDir "\QuickPhrases.ini", AppState.QuickPhraseFile, true)
            else if FileExist(AppState.QuickPhraseFile)
                FileDelete(AppState.QuickPhraseFile)

            if DirExist(AppState.QuickPhraseContentDir)
                DirDelete(AppState.QuickPhraseContentDir, true)

            if DirExist(backupDir "\QuickPhrases")
                DirCopy(backupDir "\QuickPhrases", AppState.QuickPhraseContentDir, true)

            QuickPhraseStore.Load()
        } catch {
            ok := false
        }

        try ConfigManager.Load()
        catch {
            ok := false
        }

        return ok
    }
}
