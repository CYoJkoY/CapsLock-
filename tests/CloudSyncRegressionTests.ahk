#Requires AutoHotkey v2.0

#Include "..\Config\Globals.ahk"
#Include "..\Utils\Json.ahk"
#Include "..\Utils\Hash.ahk"
#Include "..\Core\CloudSyncIdentity.ahk"
#Include "..\Core\CloudSyncModel.ahk"
#Include "..\Core\CloudSyncMerger.ahk"

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
            && Json.Stringify(0, false) == "0"
            && Json.Stringify(true, false) == "true"
            && Json.Stringify(false, false) == "false",
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
            && decoded["a"]["enabled"] === true
            && decoded["items"][2] === 0,
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
    local := MakePayload("2", [localPhrase])
    remote := MakePayload("1", [remotePhrase])

    merge := CloudSyncMerger.Merge(base, local, remote)

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
        CloudSyncModel.VerifyPackage(finalized),
        "Finalized Cloud Sync package failed integrity validation."
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
