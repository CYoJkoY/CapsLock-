#Requires AutoHotkey v2.0

#Include "..\Config\Globals.ahk"
#Include "..\Utils\Json.ahk"
#Include "..\Utils\Hash.ahk"
#Include "..\Utils\Base64.ahk"
#Include "..\Utils\HttpClient.ahk"
#Include "..\Utils\SecureStorage.ahk"
#Include "..\Core\CloudSyncIdentity.ahk"
#Include "..\Core\CloudSyncCredentials.ahk"
#Include "..\Core\CloudSyncState.ahk"
#Include "..\Core\CloudSyncModel.ahk"
#Include "..\Core\CloudSyncMerger.ahk"
#Include "..\Core\CloudSyncProvider.ahk"
#Include "..\Core\CloudSyncProviderFactory.ahk"
#Include "..\Core\Providers\GitHubGistProvider.ahk"
#Include "..\Core\Providers\GitHubRepositoryProvider.ahk"
#Include "..\Core\Providers\GoogleOAuth.ahk"
#Include "..\Core\Providers\GoogleDriveProvider.ahk"
#Include "..\Core\Providers\OneDriveOAuth.ahk"
#Include "..\Core\Providers\OneDriveProvider.ahk"
#Include "..\Core\Providers\WebDavProvider.ahk"
#Include "..\Core\CloudSyncStorage.ahk"
#Include "..\Core\CloudSyncCoordinator.ahk"

Assert(condition, message) {
    if !condition
        throw Error(message)
}


MakePayload(pasteMode, phrases) {
    config := Map()
    general := Map()
    general["pasteMode"] := pasteMode
    config["General"] := general

    payload := Map()
    payload["config"] := config
    payload["quickPhrases"] := phrases
    return payload
}

MakePhrase(id, name, category, order, content) {
    item := Map()
    item["id"] := id
    item["name"] := name
    item["category"] := category
    item["order"] := order
    item["contentFile"] := "phrase-" id ".txt"
    item["content"] := content
    return item
}

RunTests() {
    Assert(
        Json.Stringify(1, false) == "1"
            && Json.Stringify(0, false) == "0",
        "JSON primitive serialization is incorrect."
    )

    source := Map()
    source["z"] := "last"
    source["a"] := Map("n", 2, "enabled", true)
    source["items"] := [1, 0, "text"]

    encoded := Json.Stringify(source, false)
    decoded := Json.Parse(encoded)

    Assert(
        decoded is Map
            && decoded["z"] == "last"
            && decoded["a"]["n"] == 2
            && decoded["a"]["enabled"] == 1
            && decoded["items"][2] == 0,
        "JSON round-trip failed."
    )

    Assert(
        Sha256("CapsLock Cloud Sync") == "08f5c9f062d7c22ef16809d984638710cf1e905d8b56c3dcb934e134427f30c9",
        "SHA-256 helper returned an unexpected digest."
    )

    basePhrase := MakePhrase(1, "Greeting", "General", 1, "Hello")
    localPhrase := MakePhrase(1, "Greeting Edited", "General", 1, "Hello")
    remotePhrase := MakePhrase(1, "Greeting", "Updated", 1, "Hi")

    base := MakePayload("1", [basePhrase])
    localPayload := MakePayload("2", [localPhrase])
    remote := MakePayload("1", [remotePhrase])

    merge := CloudSyncMerger.Merge(base, localPayload, remote)

    Assert(merge.ok, "Independent config and phrase changes should merge.")
    Assert(
        merge.value["config"]["General"]["pasteMode"] == "2",
        "Local-only config change was not preserved."
    )
    mergedPhrase := merge.value["quickPhrases"][1]
    Assert(
        mergedPhrase["name"] == "Greeting Edited"
            && mergedPhrase["category"] == "Updated"
            && mergedPhrase["content"] == "Hi",
        "Independent Quick Phrase fields did not merge."
    )

    conflictingLocal := MakePayload(
        "2",
        [MakePhrase(1, "Greeting", "General", 1, "Local")]
    )
    conflictingRemote := MakePayload(
        "3",
        [MakePhrase(1, "Greeting", "General", 1, "Remote")]
    )

    conflict := CloudSyncMerger.Merge(
        base,
        conflictingLocal,
        conflictingRemote
    )

    Assert(
        !conflict.ok && conflict.conflicts.Length >= 2,
        "Concurrent changes were not detected as conflicts."
    )

    deletedLocal := MakePayload("1", [])
    unchangedRemote := MakePayload("1", [basePhrase])
    deletionMerge := CloudSyncMerger.Merge(
        base,
        deletedLocal,
        unchangedRemote
    )

    Assert(
        deletionMerge.ok
            && deletionMerge.value["quickPhrases"].Length == 0,
        "Local deletion against unchanged remote was not merged."
    )

    deletedVsChangedRemote := MakePayload(
        "1",
        [MakePhrase(1, "Greeting", "General", 1, "Remote change")]
    )

    deleteConflict := CloudSyncMerger.Merge(
        base,
        deletedLocal,
        deletedVsChangedRemote
    )

    Assert(
        !deleteConflict.ok,
        "Delete-versus-modify should remain a conflict."
    )

    package := CloudSyncModel.BuildPackage()
    Assert(
        package is Map
            && package["schemaVersion"] == CloudSyncModel.SchemaVersion
            && package["payload"] is Map
            && package["payload"]["quickPhrases"] is Array,
        "Versioned Cloud Sync package model is invalid."
    )

    finalized := CloudSyncModel.FinalizePackage(package)
    Assert(
        Base64EncodeText("CapsLock Cloud Sync") == "Q2Fwc0xvY2sgQ2xvdWQgU3luYw==",
        "Base64 encoding failed."
    )
    Assert(
        Base64DecodeText("Q2Fwc0xvY2sgQ2xvdWQgU3luYw==") == "CapsLock Cloud Sync",
        "Base64 decoding failed."
    )

    securePath := A_Temp "\CapsLock-CloudSync-Test.dat"
    SecureStorage.Delete(securePath)
    Assert(
        SecureStorage.Save(securePath, "DPAPI test payload"),
        "DPAPI secure storage save failed."
    )
    Assert(
        SecureStorage.Load(securePath) == "DPAPI test payload",
        "DPAPI secure storage round-trip failed."
    )
    SecureStorage.Delete(securePath)
    Assert(!FileExist(securePath), "DPAPI test file was not removed.")

    providers := [
        "gist",
        "github",
        "google-drive",
        "onedrive",
        "webdav"
    ]
    for providerName in providers {
        provider := CloudSyncProviderFactory.Create(providerName)
        Assert(IsObject(provider), "Provider factory returned no adapter for " providerName ".")
    }

    Assert(
        UriEncodePath("folder/my file.json") == "folder/my%20file.json"
            && UriEncodePath("同步/配置#.json") == "%E5%90%8C%E6%AD%A5/%E9%85%8D%E7%BD%AE%23.json",
        "Path URL encoding failed."
    )

    testProvider := {
        Name: "gist",
        Disconnected: false
    }
    testProvider.Disconnect := (*) => testProvider.Disconnected := true
    CloudSyncCoordinator.Provider := testProvider
    AppState.CloudSyncProvider := "webdav"
    switched := CloudSyncCoordinator._GetProvider()
    Assert(
        switched.Name == "webdav"
            && testProvider.Disconnected,
        "Cached Cloud Sync provider was not invalidated when the provider changed."
    )
    CloudSyncCoordinator.Provider := ""

    stateSource := FileRead(A_ScriptDir "\..\Core\CloudSyncState.ahk", "UTF-8")
    configSource := FileRead(A_ScriptDir "\..\Config\ConfigManager.ahk", "UTF-8")
    configManagerSource := configSource
    coordinatorSource := FileRead(A_ScriptDir "\..\Core\CloudSyncCoordinator.ahk", "UTF-8")
    providerFactorySource := FileRead(A_ScriptDir "\..\Core\CloudSyncProviderFactory.ahk", "UTF-8")
    gistSource := FileRead(A_ScriptDir "\..\Core\Providers\GitHubGistProvider.ahk", "UTF-8")
    driveSource := FileRead(A_ScriptDir "\..\Core\Providers\GoogleDriveProvider.ahk", "UTF-8")
    oneDriveSource := FileRead(A_ScriptDir "\..\Core\Providers\OneDriveProvider.ahk", "UTF-8")
    webDavSource := FileRead(A_ScriptDir "\..\Core\Providers\WebDavProvider.ahk", "UTF-8")
    rootSource := ReadRootSource()

    Assert(
        InStr(rootSource, "CloudSyncIdentity.Initialize()") > 0
            && InStr(rootSource, "CloudSyncState.Initialize()") > 0
            && InStr(rootSource, "CloudSyncCoordinator.Initialize()") > 0,
        "Cloud Sync startup initialization is not wired into the application entry point."
    )
    loadSource := SubStr(
        configSource,
        1,
        InStr(configSource, "static Save(markCloudSyncDirty := true)") - 1
    )
    Assert(
        InStr(loadSource, "CloudSyncCoordinator.MarkLocalChanged()") == 0,
        "ConfigManager.Load must not mark local data dirty."
    )
    Assert(
        InStr(stateSource, 'this.Set("Sync", "localDirty", "0")') > 0,
        "Cloud Sync metadata reset does not clear the persistent localDirty flag."
    )
    Assert(
        InStr(coordinatorSource, "CloudSyncDebounceTimer") > 0
            && InStr(coordinatorSource, "SetTimer(CloudSyncAutoSyncTimer, intervalMs)") > 0,
        "Automatic sync debounce and periodic timers are not separated."
    )
    Assert(
        InStr(gistSource, "expectedRevision") > 0
            && InStr(gistSource, 'providerRevision: this._Header(response.headers, "ETag")') > 0,
        "GitHub Gist provider does not preserve and revalidate its provider revision."
    )
    Assert(
        InStr(driveSource, "currentVersion != expectedRevision") > 0,
        "Google Drive provider does not revalidate its version before upload."
    )
    Assert(
        InStr(oneDriveSource, 'headers["If-Match"] := expectedRevision') > 0
            && InStr(oneDriveSource, "response.status == 412") > 0,
        "OneDrive provider does not enforce eTag compare-and-write."
    )
    Assert(
        InStr(webDavSource, "this._BaseUrl()") > 0
            && InStr(webDavSource, 'headers["If-Match"] := expectedRevision') > 0,
        "WebDAV provider is missing base-target validation or conditional writes."
    )

    Assert(
        InStr(configManagerSource, "static Save(markCloudSyncDirty := true)") > 0
            && InStr(configManagerSource, "markCloudSyncDirty && !AppState.CloudSyncApplying") > 0,
        "ConfigManager must support saves that do not dirty the synchronized payload."
    )
    Assert(
        InStr(providerFactorySource, "GetCloudSyncProviderKey()") > 0,
        "Cloud Sync provider configuration key helper is missing."
    )
    Assert(
        InStr(stateSource, "lastProviderKey") > 0
            && InStr(coordinatorSource, "InvalidateBaseline()") > 0,
        "Provider changes are not isolated from the previous synchronization baseline."
    )

    rootSource := ReadRootSource()
    Assert(
        InStr(rootSource, '#Include "Core\Providers\GitHubGistProvider.ahk"') > 0
            && InStr(rootSource, '#Include "Core\Providers\GitHubRepositoryProvider.ahk"') > 0
            && InStr(rootSource, '#Include "Core\Providers\GoogleDriveProvider.ahk"') > 0
            && InStr(rootSource, '#Include "Core\Providers\OneDriveProvider.ahk"') > 0
            && InStr(rootSource, '#Include "Core\Providers\WebDavProvider.ahk"') > 0,
        "Not all Cloud Sync provider adapters are included by the entry point."
    )

    return true
}

try {
    RunTests()
    ExitApp(0)
} catch as err {
    FileAppend(
        "Cloud Sync regression test failure: " err.Message Chr(10),
        A_WorkingDir "\tests\CloudSyncRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
