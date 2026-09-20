#Requires AutoHotkey v2.0

class CloudSyncProvider {
    Name := ""

    Connect(config := "") {
        throw Error("Provider does not implement Connect().")
    }

    ValidateConnection() {
        throw Error("Provider does not implement ValidateConnection().")
    }

    GetTarget() {
        throw Error("Provider does not implement GetTarget().")
    }

    Download() {
        throw Error("Provider does not implement Download().")
    }

    CompareVersions(localMetadata := "", remoteMetadata := "") {
        localValue := IsObject(localMetadata)
            ? Json.Stringify(localMetadata, false)
            : String(localMetadata)
        remoteValue := IsObject(remoteMetadata)
            ? Json.Stringify(remoteMetadata, false)
            : String(remoteMetadata)

        if localValue == remoteValue
            return 0
        return -1
    }

    Upload(packageText, fingerprint := "", expectedRevision := "") {
        throw Error("Provider does not implement Upload().")
    }

    Disconnect() {
        throw Error("Provider does not implement Disconnect().")
    }
}
