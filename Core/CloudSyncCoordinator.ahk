#Requires AutoHotkey v2.0

class CloudSyncCoordinator {
    static Provider := ""
    static Syncing := false
    static RetryCount := 0
    static PendingAutoSync := false

    static Initialize() {
        AppState.CloudSyncLastSuccess :=
            CloudSyncState.Get("Sync", "lastSuccessfulSync", "")
        AppState.CloudSyncConflict :=
            CloudSyncState.Get("Sync", "conflict", "0") == "1"
        AppState.CloudSyncLocalDirty :=
            CloudSyncState.Get("Sync", "localDirty", "0") == "1"

        if AppState.CloudSyncEnabled && AppState.CloudSyncAutoEnabled
            this.StartAutoSync()
    }

    static Shutdown() {
        this.StopAutoSync()
        this.Provider := ""
    }

    static MarkLocalChanged() {
        if AppState.CloudSyncApplying
            return

        AppState.CloudSyncLocalDirty := true
        CloudSyncState.Set("Sync", "localDirty", "1")

        if !AppState.CloudSyncEnabled || !AppState.CloudSyncAutoEnabled
            return

        this.PendingAutoSync := true
        this.ScheduleAutoSync()
    }

    static ScheduleAutoSync() {
        if !AppState.CloudSyncEnabled || !AppState.CloudSyncAutoEnabled
            return

        SetTimer(CloudSyncAutoSyncTimer, -5000)
    }

    static StartAutoSync() {
        this.StopAutoSync()

        intervalMs := Max(5, AppState.CloudSyncInterval) * 60000
        SetTimer(CloudSyncAutoSyncTimer, intervalMs)
    }

    static StopAutoSync() {
        try SetTimer(CloudSyncAutoSyncTimer, 0)
    }

    static _AutoSyncTick(*) {
        if !AppState.CloudSyncEnabled || !AppState.CloudSyncAutoEnabled
            return

        if !AppState.CloudSyncLocalDirty
            return

        this.PendingAutoSync := false
        this.SyncNow()
    }

    static Connect(*) {
        if this.Syncing
            return false

        if !AppState.CloudSyncEnabled {
            this._SetState("disabled")
            return false
        }

        try {
            provider := this._GetProvider()
            provider.Connect()
            provider.ValidateConnection()
            this._SetState("connected")
            return true
        } catch as err {
            this._HandleFailure(err)
            return false
        }
    }

    static ResetProvider() {
        try {
            if IsObject(this.Provider)
                this.Provider.Disconnect()
        } catch {
        }

        this.Provider := ""
        CloudSyncCredentials.Delete(AppState.CloudSyncProvider)
        AppState.CloudSyncTarget := ""
        AppState.CloudSyncConflict := false
        AppState.CloudSyncLocalDirty := false

        try IniWrite("", AppState.ConfigFile, "CloudSync", "target")
        catch {
        }

        CloudSyncState.ClearSyncMetadata()
        this._SetState(AppState.CloudSyncEnabled ? "not-configured" : "disabled")
        return true
    }

    static SyncNow(*) {
        if this.Syncing
            return false

        if !AppState.CloudSyncEnabled {
            this._SetState("disabled")
            return false
        }

        if !this._IsProviderConfigured() {
            this._SetState("not-configured")
            return false
        }

        this.Syncing := true
        this._SetState("syncing")

        try {
            provider := this._GetProvider()
            if !IsObject(provider)
                throw Error("Cloud Sync provider is unavailable.")

            provider.Connect()
            response := provider.Download()
            if !IsObject(response)
                throw Error("Provider returned an invalid download response.")

            localPackage := CloudSyncModel.FinalizePackage(CloudSyncModel.BuildPackage())
            localHash := localPackage["integrity"]["contentHash"]

            if !response.Get("exists", false) {
                upload := provider.Upload(
                    CloudSyncModel.Serialize(localPackage),
                    localHash
                )
                return this._HandleUploadSuccess(upload, localPackage)
            }

            remotePackage := CloudSyncModel.Deserialize(response.Get("text", ""))
            if !CloudSyncModel.VerifyPackage(remotePackage)
                throw Error("Remote Cloud Sync package failed integrity validation.")

            remoteFingerprint := response.Get(
                "fingerprint",
                remotePackage["integrity"]["contentHash"]
            )

            lastRemote := CloudSyncState.Get("Sync", "lastRemoteFingerprint", "")

            if lastRemote == "" {
                return this._CreateConflict(
                    localPackage,
                    remotePackage,
                    "initial-sync-existing-remote"
                )
            }

            if remoteFingerprint == lastRemote {
                if localHash == CloudSyncState.Get("Sync", "lastLocalHash", "") {
                    this._SetState("idle")
                    return true
                }

                upload := provider.Upload(
                    CloudSyncModel.Serialize(localPackage),
                    localHash,
                    response.Get("providerRevision", "")
                )
                return this._HandleUploadSuccess(upload, localPackage)
            }

            lastLocalHash := CloudSyncState.Get("Sync", "lastLocalHash", "")
            if lastLocalHash != "" && localHash == lastLocalHash {
                return this.ApplyRemote(remotePackage, response)
            }

            basePackage := this._LoadBasePackage()

            if !IsObject(basePackage) || !CloudSyncModel.VerifyPackage(basePackage) {
                return this._CreateConflict(localPackage, remotePackage, "base-missing")
            }

            merge := CloudSyncMerger.Merge(
                basePackage["payload"],
                localPackage["payload"],
                remotePackage["payload"]
            )

            if !merge.ok
                return this._CreateConflict(localPackage, remotePackage, merge.conflicts)

            mergedPackage := this._BuildPackageFromPayload(merge.value)

            currentRemote := provider.Download()
            if !IsObject(currentRemote)
                || !currentRemote.Get("exists", false)
                || currentRemote.Get("fingerprint", "") != remoteFingerprint
            {
                return false
            }

            if !CloudSyncStorage.ApplyPackage(mergedPackage)
                throw Error("Merged package could not be applied locally.")

            upload := provider.Upload(
                CloudSyncModel.Serialize(mergedPackage),
                mergedPackage["integrity"]["contentHash"],
                currentRemote.Get("providerRevision", "")
            )

            return this._HandleUploadSuccess(upload, mergedPackage)
        } catch as err {
            this._HandleFailure(err)
            return false
        } finally {
            this.Syncing := false
        }
    }

    static ApplyRemote(remotePackage, response := "") {
        if !CloudSyncModel.VerifyPackage(remotePackage)
            return false

        if !CloudSyncStorage.ApplyPackage(remotePackage)
            throw Error("Remote package could not be applied locally.")

        localHash := remotePackage["integrity"]["contentHash"]
        fingerprint := IsObject(response)
            ? response.Get("fingerprint", localHash)
            : localHash
        providerRevision := IsObject(response)
            ? response.Get("providerRevision", "")
            : ""

        this._SaveBase(remotePackage)
        this._SetSuccessfulSync(
            remotePackage["revision"]["id"],
            fingerprint,
            localHash,
            providerRevision
        )
        return true
    }

    static GetStatusText() {
        switch AppState.CloudSyncState {
            case "disabled":
                return Lang("MSG_CLOUD_SYNC_DISABLED", "Cloud Sync is disabled.")
            case "not-configured":
                return Lang("MSG_CLOUD_SYNC_NOT_CONFIGURED", "Cloud Sync is not configured.")
            case "syncing":
                return Lang("MSG_CLOUD_SYNC_SYNCING", "Synchronizing...")
            case "connected":
                return Lang("MSG_CLOUD_SYNC_CONNECTED", "Connection validated.")
            case "conflict":
                return Lang("MSG_CLOUD_SYNC_CONFLICT", "Cloud Sync conflict requires attention.")
            case "error":
                return Lang("MSG_CLOUD_SYNC_FAILED", "The last synchronization failed.")
                    " " AppState.CloudSyncLastError
            default:
                return Lang("MSG_CLOUD_SYNC_IDLE", "Cloud Sync is ready.")
        }
    }

    static Disconnect() {
        try {
            if IsObject(this.Provider)
                this.Provider.Disconnect()
        } catch {
        }

        this.Provider := ""
        this.StopAutoSync()
        AppState.CloudSyncConflict := false
        AppState.CloudSyncLocalDirty := false
        AppState.CloudSyncLastError := ""
        CloudSyncState.ClearSyncMetadata()
        this._SetState(AppState.CloudSyncEnabled ? "idle" : "disabled")
        return true
    }

    static ResolveKeepLocal() {
        if !AppState.CloudSyncConflict
            return false

        try {
            provider := this._GetProvider()
            provider.Connect()

            currentRemote := provider.Download()
            if !IsObject(currentRemote) || !currentRemote.Get("exists", false)
                throw Error("The remote sync target disappeared.")

            expectedFingerprint :=
                CloudSyncState.Get("Sync", "conflictRemoteFingerprint", "")

            currentFingerprint := currentRemote.Get("fingerprint", "")
            if expectedFingerprint == "" || currentFingerprint != expectedFingerprint
                throw Error("The remote sync target changed while the conflict was open.")

            package := CloudSyncModel.FinalizePackage(CloudSyncModel.BuildPackage())
            upload := provider.Upload(
                CloudSyncModel.Serialize(package),
                package["integrity"]["contentHash"],
                currentRemote.Get("providerRevision", "")
            )

            return this._HandleUploadSuccess(upload, package)
        } catch as err {
            this._HandleFailure(err)
            return false
        }
    }

    static ResolveUseRemote() {
        if !AppState.CloudSyncConflict
            return false

        conflictPackage := this._LoadLatestConflictPackage()
        if !IsObject(conflictPackage)
            return false

        try {
            provider := this._GetProvider()
            provider.Connect()

            currentRemote := provider.Download()
            expectedFingerprint :=
                CloudSyncState.Get("Sync", "conflictRemoteFingerprint", "")

            if !IsObject(currentRemote)
                || !currentRemote.Get("exists", false)
                || expectedFingerprint == ""
                || currentRemote.Get("fingerprint", "") != expectedFingerprint
            {
                throw Error("The remote sync target changed while the conflict was open.")
            }

            result := this.ApplyRemote(conflictPackage, currentRemote)
            return result
        } catch as err {
            this._HandleFailure(err)
            return false
        }
    }

    static ResolveMerge() {
        if !AppState.CloudSyncConflict
            return false

        conflictPackage := this._LoadLatestConflictPackage()
        basePackage := this._LoadBasePackage()
        if !IsObject(conflictPackage) || !IsObject(basePackage)
            return false

        localPackage := CloudSyncModel.FinalizePackage(CloudSyncModel.BuildPackage())

        merge := CloudSyncMerger.Merge(
            basePackage["payload"],
            localPackage["payload"],
            conflictPackage["payload"]
        )

        if !merge.ok
            return false

        mergedPackage := this._BuildPackageFromPayload(merge.value)
        if !CloudSyncStorage.ApplyPackage(mergedPackage)
            return false

        AppState.CloudSyncConflict := false

        provider := this._GetProvider()
        provider.Connect()

        currentRemote := provider.Download()
        expectedFingerprint :=
            CloudSyncState.Get("Sync", "conflictRemoteFingerprint", "")

        if !IsObject(currentRemote)
            || !currentRemote.Get("exists", false)
            || expectedFingerprint == ""
            || currentRemote.Get("fingerprint", "") != expectedFingerprint
        {
            AppState.CloudSyncConflict := true
            this._SetState("conflict")
            return false
        }

        upload := provider.Upload(
            CloudSyncModel.Serialize(mergedPackage),
            mergedPackage["integrity"]["contentHash"],
            currentRemote.Get("providerRevision", "")
        )

        return this._HandleUploadSuccess(upload, mergedPackage)
    }

    static _IsProviderConfigured() {
        switch StrLower(Trim(AppState.CloudSyncProvider)) {
            case "gist":
                return CloudSyncCredentials.Get("gist", "token", "") != ""

            case "github":
                return AppState.CloudSyncGitHubOwner != ""
                    && AppState.CloudSyncGitHubRepository != ""
                    && CloudSyncCredentials.Get("github", "token", "") != ""

            case "google-drive":
                return AppState.CloudSyncGoogleClientId != ""
                    && CloudSyncCredentials.Get("google", "refreshToken", "") != ""

            case "onedrive":
                return AppState.CloudSyncOneDriveClientId != ""
                    && CloudSyncCredentials.Get("onedrive", "refreshToken", "") != ""

            case "webdav":
                return AppState.CloudSyncWebDavUrl != ""

            default:
                return false
        }
    }

    static _GetProvider() {
        if IsObject(this.Provider)
            return this.Provider

        this.Provider := CloudSyncProviderFactory.Create(
            AppState.CloudSyncProvider
        )
        return this.Provider
    }

    static _HandleUploadSuccess(response, package) {
        if !IsObject(response)
            throw Error("Provider returned an invalid upload response.")

        if response.Get("ok", false) != true
            throw Error(
                "Cloud Sync upload failed: "
                response.Get("statusText", "provider rejected the upload")
            )

        revision := response.Get(
            "revision",
            package["revision"]["id"]
        )
        fingerprint := response.Get(
            "fingerprint",
            package["integrity"]["contentHash"]
        )
        providerRevision := response.Get("providerRevision", "")
        localHash := package["integrity"]["contentHash"]

        this._SaveBase(package)
        this._SetSuccessfulSync(revision, fingerprint, localHash, providerRevision)
        return true
    }

    static _SetSuccessfulSync(revision, fingerprint, localHash, providerRevision := "") {
        AppState.CloudSyncLastSuccess :=
            FormatTime(, "yyyy-MM-dd HH:mm:ss")
        AppState.CloudSyncLocalDirty := false
        AppState.CloudSyncConflict := false
        AppState.CloudSyncLastError := ""

        CloudSyncState.Set("Sync", "lastRemoteRevision", revision)
        CloudSyncState.Set("Sync", "lastRemoteFingerprint", fingerprint)
        CloudSyncState.Set("Sync", "lastRemoteProviderRevision", providerRevision)
        CloudSyncState.Set("Sync", "lastLocalHash", localHash)
        CloudSyncState.Set("Sync", "lastSuccessfulSync", AppState.CloudSyncLastSuccess)
        CloudSyncState.Set("Sync", "localDirty", "0")
        CloudSyncState.Set("Sync", "conflict", "0")
        CloudSyncState.Set("Sync", "lastError", "")
        this._SetState("idle")
        this.RetryCount := 0
    }

    static _CreateConflict(localPackage, remotePackage, reason) {
        conflictId := CloudSyncModel.CreateRevisionId()
        conflictPath := AppState.CloudSyncConflictDir "\" conflictId ".json"

        conflict := Map()
        conflict["reason"] := reason is Array ? "merge-conflict" : String(reason)
        conflict["local"] := localPackage
        conflict["remote"] := remotePackage

        try {
            FileAppend(
                Json.Stringify(conflict, true),
                conflictPath,
                "UTF-8"
            )
        } catch {
        }

        AppState.CloudSyncConflict := true
        CloudSyncState.Set("Sync", "conflict", "1")
        try {
            remoteFingerprint := remotePackage["integrity"]["contentHash"]
            CloudSyncState.Set("Sync", "conflictRemoteFingerprint", remoteFingerprint)
            if reason is String
                CloudSyncState.Set(
                    "Sync",
                    "conflictReason",
                    reason
                )
        } catch {
        }
        this._SetState("conflict")

        try {
            CloudSyncConflictGui.Show()
        } catch {
        }

        return false
    }

    static _BuildPackageFromPayload(payload) {
        package := CloudSyncModel.BuildPackage()
        package["payload"] := payload
        return CloudSyncModel.FinalizePackage(package)
    }

    static _SaveBase(package) {
        try {
            FileDelete(AppState.CloudSyncBaseFile)
            FileAppend(
                CloudSyncModel.Serialize(package, true),
                AppState.CloudSyncBaseFile,
                "UTF-8"
            )
            return true
        } catch {
            return false
        }
    }

    static _LoadBasePackage() {
        if !FileExist(AppState.CloudSyncBaseFile)
            return ""

        try {
            return CloudSyncModel.Deserialize(
                FileRead(AppState.CloudSyncBaseFile, "UTF-8")
            )
        } catch {
            return ""
        }
    }

    static _LoadLatestConflictPackage() {
        latest := ""
        latestTime := 0

        try {
            Loop Files, AppState.CloudSyncConflictDir "\*.json", "F" {
                if A_LoopFileTimeModified > latestTime {
                    latestTime := A_LoopFileTimeModified
                    latest := A_LoopFileFullPath
                }
            }

            if latest == ""
                return ""

            conflict := Json.Parse(FileRead(latest, "UTF-8"))
            return conflict.Has("remote") ? conflict["remote"] : ""
        } catch {
            return ""
        }
    }

    static _HandleFailure(err) {
        this.RetryCount := Min(3, this.RetryCount + 1)
        AppState.CloudSyncLastError := err.Message
        CloudSyncState.Set("Sync", "lastError", err.Message)
        this._SetState("error")

        delay := Min(600000, 30000 * (2 ** (this.RetryCount - 1)))
        if AppState.CloudSyncAutoEnabled
            SetTimer(CloudSyncRetryTimer, -delay)
    }

    static _RetryTick(*) {
        if AppState.CloudSyncEnabled && AppState.CloudSyncAutoEnabled
            this.SyncNow()
    }

    static _SetState(state) {
        AppState.CloudSyncState := state
        CloudSyncState.Set("Sync", "state", state)
    }
}


CloudSyncAutoSyncTimer(*) {
    CloudSyncCoordinator._AutoSyncTick()
}

CloudSyncRetryTimer(*) {
    CloudSyncCoordinator._RetryTick()
}
