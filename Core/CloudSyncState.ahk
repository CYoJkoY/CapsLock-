#Requires AutoHotkey v2.0

class CloudSyncState {
    static Initialize() {
        this._EnsureDirectories()

        state := this.Get("Sync", "state", "")

        ; A previous crash during a multi-file replacement must never leave
        ; the local configuration in an untracked partial state.
        if this.Get("Sync", "applyInProgress", "0") == "1" {
            if !CloudSyncStorage.RecoverInterruptedApply()
                state := "recovery-error"
            else
                state := this.Get("Sync", "state", "")
        }

        id := CloudSyncIdentity.GetId()
        name := CloudSyncIdentity.GetName()

        this.Set("Device", "id", id)
        this.Set("Device", "name", name)

        providerKey := GetCloudSyncProviderKey()
        previousProviderKey := this.Get("Sync", "lastProviderKey", "")
        if state != "recovery-error"
            && previousProviderKey != ""
            && previousProviderKey != providerKey
        {
            this.ClearSyncMetadata()
            state := AppState.CloudSyncEnabled ? "idle" : "disabled"
            if AppState.CloudSyncEnabled {
                this.Set("Sync", "localDirty", "1")
                AppState.CloudSyncLocalDirty := true
            }
        }

        if state == "recovery-error" {
            this.Set("Sync", "state", "recovery-error")
        } else if !AppState.CloudSyncEnabled {
            state := "disabled"
            this.Set("Sync", "state", state)
        } else if state == "" || state == "disabled" {
            state := "idle"
            this.Set("Sync", "state", state)
        } else {
            this.Set("Sync", "state", state)
        }

        AppState.CloudSyncLastSuccess :=
            this.Get("Sync", "lastSuccessfulSync", "")
        AppState.CloudSyncConflict :=
            this.Get("Sync", "conflict", "0") == "1"
        AppState.CloudSyncLocalDirty :=
            this.Get("Sync", "localDirty", "0") == "1"
        AppState.CloudSyncState :=
            this.Get("Sync", "state", AppState.CloudSyncEnabled ? "idle" : "disabled")
        AppState.CloudSyncLastError :=
            this.Get("Sync", "lastError", "")
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
        this.Set("Sync", "lastRemoteProviderRevision", "")
        this.Set("Sync", "lastRemoteFingerprint", "")
        this.Set("Sync", "lastLocalHash", "")
        this.Set("Sync", "lastSuccessfulSync", "")
        this.Set("Sync", "state", AppState.CloudSyncEnabled ? "idle" : "disabled")
        this.Set("Sync", "conflict", "0")
        this.Set("Sync", "localDirty", "0")
        this.Set("Sync", "conflictRemoteFingerprint", "")
        this.Set("Sync", "conflictReason", "")
        this.Set("Sync", "lastError", "")
        this.Set("Sync", "lastProviderKey", GetCloudSyncProviderKey())
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
