#Requires AutoHotkey v2.0

; Optional AHK <-> C# boundary. Hotkeys, clipboard ownership, metadata, disk
; storage and GUIs stay in AHK. The CLR is started only by a requested service,
; never by Configure(), history loading, or rule preparation at app startup.
; The first failure disables C# for the session; AHK remains authoritative.
class Services {
    static backend := "ahk"
    static ready := false
    static tripped := false
    static reason := "not configured"

    static calls := 0
    static fallbacks := 0
    static errors := 0
    static historyLoads := 0
    static historyDeltas := 0

    static assemblyPath := ""
    static bridgePath := ""
    static history := ""
    static historyType := ""
    static ignore := ""
    static clipboard := ""
    static historyRevision := -1
    static historySource := ""
    static historyCount := 0

    static Configure() {
        value := "ahk"
        try value := StrLower(Trim(String(AppState.ServiceBackend)))
        if value != "csharp"
            value := "ahk"
        if value != this.backend
            this.InvalidateHistory(value == "ahk")
        this.backend := value
        if !this.tripped
            this.reason := (value == "ahk") ? "backend is ahk" : (this.ready ? "ready" : "waiting for first service call")
        return value
    }

    static IsEnabled() {
        return this.backend == "csharp" && !this.tripped
    }

    static DefaultAssemblyPath() {
        return A_ScriptDir "\lib\CapsLockSharp.dll"
    }

    static DefaultBridgePath() {
        return A_ScriptDir "\lib\ahk#\lib\ahk#.bridge.dll"
    }

    static Boot() {
        global CS
        if !this.IsEnabled()
            return false
        if this.ready
            return true

        try {
            if !this.HaveBridge()
                throw Error("AHK# is not installed")
            ; A compiled EXE carries the services and the bridge as resources.
            ; Unpacking them is local disk work only - no network, no compiler
            ; and still no CLR - and is skipped when an explicit path override
            ; is in effect. Building or downloading belongs to the one-click
            ; setup, never to a service call.
            CSharpRuntime.ExtractPackaged()
            dll := this.assemblyPath ? this.assemblyPath : this.DefaultAssemblyPath()
            bridge := this.bridgePath ? this.bridgePath : this.DefaultBridgePath()
            if !FileExist(dll)
                throw Error("CapsLockSharp.dll not found at " dll)
            if !FileExist(bridge)
                throw Error("AHK# bridge DLL not found at " bridge)

            ; Never ask AHK# to build/download anything on the user's machine.
            ; Its developer flag would rebuild even an existing bridge DLL.
            if EnvGet("AHKSHARP_DEV") != ""
                throw Error("AHKSHARP_DEV runtime builds are not supported by Services")
            ; Keep its default hash verification enabled.
            CS.Config.BridgeDll := bridge
            CS.Config.ShowErrorGui := false
            CS.LoadAssembly(dll)
            this.history := CS.CreateObject("CapsLockSharp.HistoryService")
            this.historyType := CS("CapsLockSharp.HistoryService")
            this.ignore := CS.CreateObject("CapsLockSharp.IgnoreMatcher")
            ; Static C# classes are type references, not constructible objects.
            this.clipboard := CS("CapsLockSharp.ClipboardService")
            this.ready := true
            this.reason := "ready"
            return true
        } catch as err {
            this.Trip("boot failed: " err.Message)
            return false
        }
    }

    static HaveBridge() {
        global CS
        return IsSet(CS) && IsObject(CS)
    }

    static Trip(reason) {
        this.errors++
        this.tripped := true
        this.reason := reason
        this.InvalidateHistory(true)
    }

    static Status() {
        return Map(
            "backend", this.backend, "ready", this.ready,
            "tripped", this.tripped, "reason", this.reason,
            "calls", this.calls, "fallbacks", this.fallbacks, "errors", this.errors,
            "history_loads", this.historyLoads, "history_deltas", this.historyDeltas
        )
    }

    static Dispatch(csharpFn, ahkFn) {
        if this.IsEnabled() && this.Boot() {
            try {
                result := csharpFn()
                this.calls++
                return result
            } catch as err {
                this.Trip("call failed: " err.Message)
            }
        }
        this.fallbacks++
        return ahkFn()
    }

    ; Length framing avoids delimiter collisions in multiline clipboard text.
    ; Both runtimes count UTF-16 code units. Preallocate once for bulk inputs.
    static PackStrings(values) {
        total := 0
        for value in values {
            length := StrLen(value)
            total += StrLen(String(length)) + 1 + length
        }
        payload := ""
        VarSetStrCapacity(&payload, total)
        for value in values
            payload .= StrLen(value) ":" value
        return payload
    }

    static UnpackStrings(payload) {
        values := []
        offset := 1
        total := StrLen(payload)
        while offset <= total {
            colon := InStr(payload, ":", true, offset)
            if !colon
                throw Error("Missing service string length")
            digits := SubStr(payload, offset, colon - offset)
            if !(digits ~= "^[0-9]+$")
                throw Error("Invalid service string length")
            length := Integer(digits)
            offset := colon + 1
            if length > total - offset + 1
                throw Error("Truncated service string payload")
            values.Push(SubStr(payload, offset, length))
            offset += length
        }
        return values
    }

    static InvalidateHistory(discard := false) {
        this.historyRevision := -1
        this.historySource := ""
        this.historyCount := 0
        if discard
            this.history := ""  ; let obsolete managed text become collectible
    }

    static SyncHistory() {
        if this.historyRevision == HistoryManager.revision
            && this.historySource == AppState.History
            && this.historyCount == AppState.History.Length
            return

        ; Prevent a clipboard/timer mutation halfway through the one-time
        ; snapshot. No worker callbacks, Send, or GUI work runs in this section.
        wasCritical := A_IsCritical
        Critical("On")
        try {
            if !IsObject(this.history)
                this.history := this.historyType.Call()
            texts := []
            for item in AppState.History
                texts.Push(item["text"])
            this.history.LoadSnapshot(this.PackStrings(texts))
            this.historyRevision := HistoryManager.revision
            this.historySource := AppState.History
            this.historyCount := AppState.History.Length
            this.historyLoads++
            this.calls++
        } finally {
            Critical(wasCritical)
        }
    }

    static HistoryFindDuplicate(candidate) {
        if !this.IsEnabled() {
            this.fallbacks++
            return ServicesHistoryFindDuplicateResidentAhk(candidate)
        }
        return this.Dispatch(
            ServicesHistoryFindDuplicateCSharp.Bind(candidate),
            ServicesHistoryFindDuplicateResidentAhk.Bind(candidate)
        )
    }

    static HistorySearch(query) {
        ; An unfiltered page needs no managed scan or all-indices COM transfer.
        if query == "" {
            indices := []
            loop AppState.History.Length
                indices.Push(A_Index)
            return indices
        }
        if !this.IsEnabled() {
            this.fallbacks++
            return ServicesHistorySearchAhk(query)
        }
        return this.Dispatch(ServicesHistorySearchCSharp.Bind(query), ServicesHistorySearchAhk.Bind(query))
    }

    ; Notifications run only for an already resident, up-to-date index. They
    ; never boot the CLR. If the backend was disabled during an edit, the next
    ; query rebuilds once from authoritative AHK data instead of replaying it.
    static CanUpdateHistory(previousRevision) {
        if this.IsEnabled() && this.ready && this.historyRevision == previousRevision
            && this.historySource == AppState.History
            return true
        this.InvalidateHistory(true)
        return false
    }

    static HistoryAdded(text, duplicateIndex, max, previousRevision) {
        if this.CanUpdateHistory(previousRevision)
            this.ApplyHistoryDelta(ServicesHistoryAddedCSharp.Bind(text, duplicateIndex, max))
    }

    static HistoryDeleted(index, previousRevision) {
        if this.CanUpdateHistory(previousRevision)
            this.ApplyHistoryDelta(ServicesHistoryDeletedCSharp.Bind(index))
    }

    static HistoryTrimmed(max, previousRevision) {
        if this.CanUpdateHistory(previousRevision)
            this.ApplyHistoryDelta(ServicesHistoryTrimmedCSharp.Bind(max))
    }

    static ApplyHistoryDelta(fn) {
        try {
            count := Integer(fn())
            if count != AppState.History.Length
                throw Error("Resident history count mismatch")
            this.historyRevision := HistoryManager.revision
            this.historyCount := count
            this.historyDeltas++
            this.calls++
        } catch as err {
            ; AHK has already committed the edit. Never apply it a second time.
            this.Trip("history delta failed: " err.Message)
        }
    }

    static IgnoreMatch(path) {
        return this.Dispatch(ServicesIgnoreMatchCSharp.Bind(path), ServicesIgnoreMatchAhk.Bind(path))
    }

    static FilterFilePaths(paths) {
        return this.Dispatch(ServicesFilterFilePathsCSharp.Bind(paths), ServicesFilterFilePathsAhk.Bind(paths))
    }

    static LooksLikeFilePathList(text) {
        return this.Dispatch(
            ServicesLooksLikeFilePathListCSharp.Bind(text), ServicesLooksLikeFilePathListAhk.Bind(text)
        )
    }
}

ServicesHistoryFindDuplicateCSharp(candidate) {
    Services.SyncHistory()
    index := Integer(Services.history.FindDuplicate(candidate))
    if index < -1 || index >= AppState.History.Length
        throw Error("Invalid resident duplicate index")
    if index >= 0 && !(AppState.History[index + 1]["text"] == candidate)
        throw Error("Resident duplicate text mismatch")
    return index + 1
}

ServicesHistoryFindDuplicateResidentAhk(candidate) {
    i := AppState.History.Length
    while i > 0 {
        if AppState.History[i]["text"] == candidate
            return i
        i--
    }
    return 0
}

; Retained for the stateless/naive benchmark, not used by HistoryManager.Add.
ServicesHistoryFindDuplicateAhk(texts, candidate) {
    i := texts.Length
    while i > 0 {
        if texts[i] == candidate
            return i
        i--
    }
    return 0
}

ServicesHistoryAddedCSharp(text, duplicateIndex, max) {
    return Services.history.ApplyAdd(text, duplicateIndex - 1, max)
}

ServicesHistoryDeletedCSharp(index) {
    return Services.history.DeleteAt(index - 1)
}

ServicesHistoryTrimmedCSharp(max) {
    return Services.history.TrimTo(max)
}

ServicesHistorySearchCSharp(query) {
    Services.SyncHistory()
    result := Services.history.SearchIndices(query)
    indices := []
    previous := 0
    if result == ""
        return indices
    for value in StrSplit(result, ",") {
        if !(value ~= "^[0-9]+$")
            throw Error("Invalid resident search index")
        index := Integer(value) + 1
        if index <= previous || index > AppState.History.Length
            throw Error("Resident search indices are out of order/range")
        indices.Push(index)
        previous := index
    }
    return indices
}

ServicesHistorySearchAhk(query) {
    indices := []
    for index, item in AppState.History {
        text := item["text"]
        if query == "" || InStr(text, query) || InStr(ServicesHistoryPreviewAhk(text), query)
            indices.Push(index)
    }
    return indices
}

ServicesHistoryPreviewAhk(text) {
    display := RegExReplace(SubStr(text, 1, 80), "[\r\n\t\v\f]+", " ")
    return display . (StrLen(text) > 80 ? "…" : "")
}

ServicesIgnoreMatchCSharp(path) {
    rules := FileHelper.ServiceRules()
    return Services.ignore.IsMatch(rules[1], rules[2], path) ? true : false
}

ServicesIgnoreMatchAhk(path) {
    return FileHelper.ShouldIgnoreAhk(path)
}

ServicesFilterFilePathsCSharp(paths) {
    rules := FileHelper.ServiceRules()
    result := Services.ignore.FilterPaths(rules[1], rules[2], Services.PackStrings(paths))
    return Services.UnpackStrings(result)
}

ServicesFilterFilePathsAhk(paths) {
    kept := []
    for path in paths
        if !FileHelper.ShouldIgnoreAhk(path)
            kept.Push(path)
    return kept
}

ServicesLooksLikeFilePathListCSharp(text) {
    return Services.clipboard.LooksLikeFilePathList(text) ? true : false
}

ServicesLooksLikeFilePathListAhk(text) {
    if text == "" || !InStr(text, "`n")
        return false
    first := StrSplit(text, "`n", "`r")[1]
    return FileExist(first) ? true : false
}
