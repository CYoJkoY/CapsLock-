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

    static SyncNow(*) {
        if this.Syncing
            return false

        if !AppState.CloudSyncEnabled {
            this._SetState("disabled")
            return false
        }

        if Trim(AppState.CloudSyncProvider) == "" || Trim(AppState.CloudSyncTarget) == "" {
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

            if lastRemote == "" || remoteFingerprint == lastRemote {
                upload := provider.Upload(
                    CloudSyncModel.Serialize(localPackage),
                    localHash
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
            if !CloudSyncStorage.ApplyPackage(mergedPackage)
                throw Error("Merged package could not be applied locally.")

            upload := provider.Upload(
                CloudSyncModel.Serialize(mergedPackage),
                mergedPackage["integrity"]["contentHash"]
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

        this._SaveBase(remotePackage)
        this._SetSuccessfulSync(
            remotePackage["revision"]["id"],
            fingerprint,
            localHash
        )
        return true
    }

    static Disconnect() {
        try {
            if IsObject(this.Provider)
                this.Provider.Disconnect()
        } catch {
        }

        this.Provider := ""
        AppState.CloudSyncConflict := false
        AppState.CloudSyncLocalDirty := false
        CloudSyncState.ClearSyncMetadata()
        this._SetState(AppState.CloudSyncEnabled ? "idle" : "disabled")
        return true
    }

    static ResolveKeepLocal() {
        return this.SyncNow()
    }

    static ResolveUseRemote() {
        if !AppState.CloudSyncConflict
            return false

        conflictPackage := this._LoadLatestConflictPackage()
        if !IsObject(conflictPackage)
            return false

        result := this.ApplyRemote(conflictPackage)
        if result
            AppState.CloudSyncConflict := false
        return result
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
        upload := provider.Upload(
            CloudSyncModel.Serialize(mergedPackage),
            mergedPackage["integrity"]["contentHash"]
        )

        return this._HandleUploadSuccess(upload, mergedPackage)
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
        localHash := package["integrity"]["contentHash"]

        this._SaveBase(package)
        this._SetSuccessfulSync(revision, fingerprint, localHash)
        return true
    }

    static _SetSuccessfulSync(revision, fingerprint, localHash) {
        AppState.CloudSyncLastSuccess :=
            FormatTime(, "yyyy-MM-dd HH:mm:ss")
        AppState.CloudSyncLocalDirty := false
        AppState.CloudSyncConflict := false

        CloudSyncState.Set("Sync", "lastRemoteRevision", revision)
        CloudSyncState.Set("Sync", "lastRemoteFingerprint", fingerprint)
        CloudSyncState.Set("Sync", "lastLocalHash", localHash)
        CloudSyncState.Set("Sync", "lastSuccessfulSync", AppState.CloudSyncLastSuccess)
        CloudSyncState.Set("Sync", "localDirty", "0")
        CloudSyncState.Set("Sync", "conflict", "0")
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
        this._SetState("conflict")
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
