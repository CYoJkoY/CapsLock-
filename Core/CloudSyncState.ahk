#Requires AutoHotkey v2.0

class CloudSyncState {
    static Initialize() {
        this._EnsureDirectories()

        ; A previous crash during a multi-file replacement must never leave
        ; the local configuration in an untracked partial state.
        if this.Get("Sync", "applyInProgress", "0") == "1"
            CloudSyncStorage.RecoverInterruptedApply()

        id := CloudSyncIdentity.GetId()
        name := CloudSyncIdentity.GetName()

        this.Set("Device", "id", id)
        this.Set("Device", "name", name)
        this.Set("Sync", "state", AppState.CloudSyncEnabled ? "idle" : "disabled")
        this.Set("Sync", "applyInProgress", "0")

        AppState.CloudSyncLastSuccess :=
            this.Get("Sync", "lastSuccessfulSync", "")
        AppState.CloudSyncConflict :=
            this.Get("Sync", "conflict", "0") == "1"
        AppState.CloudSyncLocalDirty :=
            this.Get("Sync", "localDirty", "0") == "1"
    }

    static Get(section, key, default := "") {
        this._EnsureDirectories()

        try {
            return IniRead(AppState.CloudSyncStateFile, section, key, default)
        } catch {
            return default
        }
    }

    static Set(section, key, value) {
        this._EnsureDirectories()

        try {
            IniWrite(value, AppState.CloudSyncStateFile, section, key)
            return true
        } catch {
            return false
        }
    }

    static ClearSyncMetadata() {
        this.Set("Sync", "lastRemoteRevision", "")
        this.Set("Sync", "lastRemoteFingerprint", "")
        this.Set("Sync", "lastLocalHash", "")
        this.Set("Sync", "lastSuccessfulSync", "")
        this.Set("Sync", "state", AppState.CloudSyncEnabled ? "idle" : "disabled")
        this.Set("Sync", "conflict", "0")
    }

    static _EnsureDirectories() {
        if !DirExist(AppState.CloudSyncDir)
            DirCreate(AppState.CloudSyncDir)
        if !DirExist(AppState.CloudSyncBackupDir)
            DirCreate(AppState.CloudSyncBackupDir)
        if !DirExist(AppState.CloudSyncConflictDir)
            DirCreate(AppState.CloudSyncConflictDir)
    }
}
