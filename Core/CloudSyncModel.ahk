#Requires AutoHotkey v2.0

class CloudSyncModel {
    static SchemaVersion := 1

    static BuildPackage() {
        package := Map()
        package["schemaVersion"] := this.SchemaVersion
        package["applicationVersion"] := this.GetApplicationVersion()

        device := Map()
        device["id"] := CloudSyncIdentity.GetId()
        device["name"] := CloudSyncIdentity.GetName()
        package["device"] := device

        revision := Map()
        revision["id"] := this.CreateRevisionId()
        revision["createdAt"] := FormatTime(, "yyyy-MM-ddTHH:mm:ssZ")
        revision["deviceId"] := device["id"]
        package["revision"] := revision

        payload := Map()
        payload["config"] := CloudSyncSerializer.ExportConfig()
        payload["quickPhrases"] := CloudSyncSerializer.ExportQuickPhrases()
        package["payload"] := payload

        package["integrity"] := Map()
        return package
    }

    static CanonicalContent(package) {
        clone := Map()

        for key, value in package {
            if key == "integrity"
                continue
            clone[key] := value
        }

        return Json.Stringify(clone, false)
    }

    static FinalizePackage(package) {
        content := this.CanonicalContent(package)

        integrity := Map()
        integrity["algorithm"] := "SHA-256"
        integrity["contentHash"] := Sha256(content)
        package["integrity"] := integrity

        return package
    }

    static VerifyPackage(package) {
        if !IsObject(package) || !(package is Map)
            return false

        if !package.Has("schemaVersion") || package["schemaVersion"] != this.SchemaVersion
            return false

        if !package.Has("revision") || !(package["revision"] is Map)
            return false

        if !package["revision"].Has("id") || package["revision"]["id"] == ""
            return false

        if !package.Has("payload") || !(package["payload"] is Map)
            return false

        if !package["payload"].Has("config")
            || !package["payload"].Has("quickPhrases")
            || !(package["payload"]["quickPhrases"] is Array)
            return false

        if !package.Has("integrity") || !(package["integrity"] is Map)
            return false

        if package["integrity"].Get("algorithm", "") != "SHA-256"
            return false

        expected := package["integrity"].Get("contentHash", "")
        if expected == ""
            return false

        actual := Sha256(this.CanonicalContent(package))
        return StrLower(expected) == StrLower(actual)
    }

    static Serialize(package, pretty := true) {
        return Json.Stringify(package, pretty)
    }

    static Deserialize(text) {
        try
            return Json.Parse(text)
        catch
            return ""
    }

    static CreateRevisionId() {
        return FormatTime(, "yyyyMMddHHmmss")
            "-" A_TickCount
            "-" Random(100000, 999999)
    }

    static GetApplicationVersion() {
        try {
            if InStr(StrLower(A_ScriptFullPath), ".exe")
                return FileGetVersion(A_ScriptFullPath)
        } catch {
        }

        return "source-" A_AhkVersion
    }
}
