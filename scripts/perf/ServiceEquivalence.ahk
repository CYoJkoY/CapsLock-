#Requires AutoHotkey v2.0
#SingleInstance Off

; Headless checks using the REAL AHK implementations. No hotkeys/GUI/clipboard
; changes. Pass -CSharp to require the pinned bridge and compiled assembly.
#Include *i ..\..\lib\ahk#\lib\ahk#.ahk
#Include ..\..\Config\Globals.ahk
#Include ..\..\Config\Encryption.ahk
#Include ..\..\Core\Services.ahk
#Include ..\..\Core\CSharpRuntime.ahk
#Include ..\..\Core\FileValidation.ahk
#Include ..\..\Core\FileOperations.ahk
#Include ..\..\History\HistoryStorage.ahk

checks := 0
failures := 0

Check(condition, name) {
    global checks, failures
    checks++
    if !condition {
        failures++
        FileAppend("FAIL " name "`n", "*", "UTF-8-RAW")
    }
}

CheckSame(expected, actual, name) {
    Check(Services.PackStrings(expected) == Services.PackStrings(actual), name)
}

ReplaceHistory(texts, max := 10000) {
    AppState.History := []
    AppState.MaxHistory := max
    AppState.IgnoreNextClipChange := false
    for text in texts
        AppState.History.Push(Map("text", text, "time", "2026-10-02 00:00:00", "source", "test"))
    HistoryManager.Replaced()
}

HistoryTexts() {
    texts := []
    for item in AppState.History
        texts.Push(item["text"])
    return texts
}

CheckResident(name) {
    Services.SyncHistory()
    Check(Services.history.ExportSnapshot() == Services.PackStrings(HistoryTexts()), name)
    Check(!Services.tripped, name " (no fallback)")
}

SetRules(rules) {
    AppState.IgnorePatterns := rules
    FileHelper.BuildIgnoreRegexes()
}

class FailingIgnore {
    IsMatch(simple, complex, path) {
        throw Error("injected scalar failure")
    }
    FilterPaths(simple, complex, paths) {
        ; Exercise the response decoder's guard as well as the circuit breaker.
        return "100:truncated"
    }
}

class FailingDelta {
    __New(realHistory) {
        this.real := realHistory
    }
    FindDuplicate(text) {
        return this.real.FindDuplicate(text)
    }
    ApplyAdd(text, duplicate, max) {
        throw Error("injected post-commit delta failure")
    }
}

TestCommon() {
    strings := ["", "0:|,`n`r", "中文🚀", Chr(31) ":delimiter", "tail"]
    CheckSame(strings, Services.UnpackStrings(Services.PackStrings(strings)), "UTF-16 wire framing")
    ReplaceHistory(["dup", "middle", "dup", "tail"])
    Check(Services.HistoryFindDuplicate("dup") == 3, "oldest duplicate")
    Check(Services.HistoryFindDuplicate("DUP") == 0, "case-sensitive duplicate")
    revision := HistoryManager.revision
    HistoryManager.Add("dup")
    Check(HistoryManager.revision == revision, "top duplicate is a no-op")
    HistoryManager.Add("middle")
    CheckSame(["middle", "dup", "dup", "tail"], HistoryTexts(), "move old duplicate to top")
    HistoryManager.Delete(0)
    HistoryManager.Delete(-1)
    CheckSame(["middle", "dup", "dup", "tail"], HistoryTexts(), "invalid deletion is a no-op")
    HistoryManager.Delete(2)
    HistoryManager.Trim(2)
    CheckSame(["middle", "dup"], HistoryTexts(), "delete and trim")
    ReplaceHistory(["alpha`r`n`tBeta", "ÉCOLE", "你好🚀", "a" . Repeat("x", 80) . "tail"])
    CheckSame([1], Services.HistorySearch("alpha beta"), "collapsed-preview search")
    CheckSame([], Services.HistorySearch("école"), "AHK default search does not fold non-ASCII case")
    CheckSame([2], Services.HistorySearch("École"), "ASCII-insensitive search beside Unicode")
    CheckSame([4], Services.HistorySearch("tail"), "search beyond preview boundary")
    CheckSame([4], Services.HistorySearch("…"), "preview ellipsis search")
    CheckSame([1, 2, 3, 4], Services.HistorySearch(""), "empty query matches all")
}

Repeat(text, count) {
    result := ""
    loop count
        result .= text
    return result
}

TestResident() {
    ReplaceHistory(["dup", "middle", "dup", "tail", "a`r`nb", "🚀:|,"], 127)
    Check(Services.HistoryFindDuplicate("missing") == 0, "first resident miss")
    CheckResident("initial resident snapshot")
    loads := Services.historyLoads
    loop 1000 {
        HistoryManager.Add("new-" A_Index, "test")
        if Mod(A_Index, 13) == 0
            HistoryManager.Delete(2)
        if Mod(A_Index, 17) == 0
            HistoryManager.Add("new-" (A_Index - 3), "test")
        Check(Services.HistoryFindDuplicate("new-" A_Index) == ServicesHistoryFindDuplicateResidentAhk("new-" A_Index),
            "warm duplicate rank " A_Index)
    }
    HistoryManager.Trim(16)
    CheckResident("resident add/delete/trim/wraparound")
    Check(Services.historyLoads == loads, "warm edits never resend the history table")
    HistoryManager.Trim(0)
    CheckResident("resident disable/clear")
    Check(Services.history.Count == 0, "cleared resident index")

    ReplaceHistory(["case", "CASE", "01", "1", "é", "É", "你好🚀", "a`r`n`tB", "`v`f", "KΣİı", "kσi", "alpha" Chr(0x85) Chr(0x2028) Chr(0x2029) "Beta"])
    for text in HistoryTexts()
        Check(Services.HistoryFindDuplicate(text) == ServicesHistoryFindDuplicateResidentAhk(text), "exact duplicate parity " text)
    for query in ["", "case", "01", "1", "é", "É", "你好", "🚀", "a b", "alpha beta", " ", "missing", "K", "K", "Σ", "σ", "İ", "i", "ı"]
        CheckSame(ServicesHistorySearchAhk(query), Services.HistorySearch(query), "search parity " query)
    CheckResident("replacement snapshot")

    AppState.ServiceBackend := "ahk"
    Services.Configure()
    Check(!IsObject(Services.history), "disabled backend releases resident text reference")
    HistoryManager.Add("edited-while-disabled")
    AppState.ServiceBackend := "csharp"
    Services.Configure()
    Check(Services.HistoryFindDuplicate("edited-while-disabled") == 1, "backend toggle resynchronizes")
    CheckResident("backend toggle snapshot")

    HistoryManager.ScheduleSave()
    HistoryManager.ForceSave()
    HistoryManager.Add("not-on-disk")
    HistoryManager.Load()
    Check(Services.HistoryFindDuplicate("not-on-disk") == 0, "disk reload invalidates resident snapshot")
    CheckResident("binary storage remains compatible")
    HistoryManager.Trim(0)
    HistoryManager.ForceSave()
    HistoryManager.Add("after-empty-save")
    HistoryManager.Load()
    Check(AppState.History.Length == 0, "zero-count binary reload replaces in-memory history")
    Check(Services.HistoryFindDuplicate("after-empty-save") == 0, "empty reload invalidates index")
    CheckResident("empty binary snapshot")
}

TestIgnore(work) {
    paths := [work "\keep.txt", work "\DROP.TMP", work "\readme.md", "C:\repo\obj\a.cs", "C:\repo\OBJ\a.cs",
        "C:\repo\node_modules\x.js", "build\a.txt", "temp1", "nested\temp1", "a\deep\b\file.txt", "a\b\file.txt", "C:file.txt", "C:", "", "C:/repo/file.txt", "http://example.test/file.txt", "file://C:\repo\file.txt"]
    for rule in ["*.tmp", "*.txt;*.md", "*.*", "**", "file.txt", "obj", "?emp*", "**/obj/**", "**/node_modules/**",
        "^build/**", "a/**/b", "**/*.cs", "**/*.cs/", "# comment", "!keep.txt"] {
        SetRules([rule])
        for path in paths {
            Check(FileHelper.ShouldIgnoreAhk(path) == Services.IgnoreMatch(path), "ignore scalar parity " rule " / " path)
            ; The app's single-path check never crosses the bridge (measured slower).
            calls := Services.calls
            Check(FileHelper.ShouldIgnore(path) == FileHelper.ShouldIgnoreAhk(path), "ShouldIgnore is the AHK matcher " rule " / " path)
            Check(Services.calls == calls, "ShouldIgnore does not call C# " rule " / " path)
        }
        CheckSame(ServicesFilterFilePathsAhk(paths), Services.FilterFilePaths(paths), "ignore batch parity " rule)
        Check(!Services.tripped, "ignore rules do not trip backend " rule)
    }
    SetRules(["*.tmp", "**/obj/**"])
    CheckSame(ServicesFilterFilePathsAhk(paths), Services.FilterFilePaths(paths), "combined ignore rules")
    Check(Services.ignore.CacheCount == 1, "only one compiled rule set is retained")

    root := work "\tree"
    DirCreate(root "\obj")
    DirCreate(root "\nested")
    loop 100 {
        FileAppend("keep", root "\nested\file" A_Index ".txt")
        FileAppend("drop", root "\nested\file" A_Index ".tmp")
    }
    FileAppend("obj", root "\obj\a.txt")
    FileAppend("root", root "\root.txt")
    Services.backend := "ahk"
    expected := FileHelper.CollectFilesFromFolder(root, true, ["existing"])
    Services.backend := "csharp"
    calls := Services.calls
    actual := FileHelper.CollectFilesFromFolder(root, true, ["existing"])
    CheckSame(expected, actual, "native recursive enumeration order and existing output list")
    ; The root-folder check is a single-path ShouldIgnore (AHK); the 200+ files
    ; are filtered in one crossing.
    Check(Services.calls - calls == 1, "one batch crossing for the whole walk, not one per file")
    Services.backend := "ahk"
    expected := FileHelper.CollectFilesFromFolder(root, false)
    Services.backend := "csharp"
    CheckSame(expected, FileHelper.CollectFilesFromFolder(root, false), "non-recursive enumeration parity")
    calls := Services.calls
    text := FileHelper.ReadMultipleFilesAsText([root "\root.txt", root "\nested\file1.tmp"])
    Check(InStr(text, "root.txt") && !InStr(text, "file1.tmp"), "text file batch respects rules")
    Check(Services.calls - calls == 1, "text-file input uses one filtering crossing")
    Check(!Services.tripped, "file batches actually ran in C#")
}

TestFailures() {
    SetRules(["*.tmp"])
    realIgnore := Services.ignore
    Services.ignore := FailingIgnore()
    before := Services.errors
    CheckSame(["keep.txt"], Services.FilterFilePaths(["drop.tmp", "keep.txt"]), "malformed batch falls back to real matcher")
    Check(Services.tripped && Services.errors == before + 1, "batch failure opens circuit once")
    Check(!Services.Boot(), "tripped backend cannot report a successful boot")
    Check(FileHelper.ShouldIgnore("drop.tmp"), "tripped backend still honors ignore rules")
    Check(Services.errors == before + 1, "breaker prevents repeated exceptions")

    ; Test-only reset. Configure() deliberately cannot reset a breaker in the app.
    Services.tripped := false
    Check(Services.IgnoreMatch("drop.tmp"), "scalar failure falls back to real matcher, not false")
    Check(Services.tripped && Services.errors == before + 2, "scalar failure opens circuit")
    Services.ignore := realIgnore
    Services.tripped := false
    ReplaceHistory(["seed"])
    Services.HistoryFindDuplicate("missing")
    realHistory := Services.history
    Services.history := FailingDelta(realHistory)
    HistoryManager.Add("committed-once")
    Check(Services.tripped, "post-commit delta failure opens circuit")
    CheckSame(["committed-once", "seed"], HistoryTexts(), "delta failure never reapplies an AHK edit")
    Services.history := realHistory
    Check(Services.HistoryFindDuplicate("committed-once") == 1, "history lookup falls back after delta failure")
}

Main() {
    global checks, failures
    root := RegExReplace(A_ScriptDir, "\\scripts\\perf$", "")
    work := A_Temp "\CapsLockServiceTests-" DllCall("GetCurrentProcessId") "-" A_TickCount
    DirCreate(work)
    AppState.HistoryFile := work "\history.bin"
    Services.assemblyPath := root "\lib\CapsLockSharp.dll"
    Services.bridgePath := root "\lib\ahk#\lib\ahk#.bridge.dll"
    requireCSharp := false
    for arg in A_Args
        if arg == "-CSharp"
            requireCSharp := true

    try {
        Services.Configure()
        TestCommon()
        Check(!Services.ready, "default AHK backend never boots CLR")
        if requireCSharp {
            AppState.ServiceBackend := "csharp"
            Services.Configure()
            HistoryManager.Load()
            SetRules(["*.tmp"])
            Check(!Services.ready, "configure/load/rule preparation are lazy")
            if !Services.Boot()
                throw Error("Required C# backend unavailable: " Services.reason)
            TestCommon()
            TestResident()
            TestIgnore(work)
            Check(!Services.tripped, "equivalence checks did not silently fall back")
            TestFailures()
        }

        ; Missing runtime/assembly costs one failure, then correct AHK behavior.
        Services.ready := false
        Services.tripped := false
        Services.assemblyPath := work "\missing.dll"
        Services.InvalidateHistory()
        AppState.ServiceBackend := "csharp"
        Services.Configure()
        SetRules(["*.tmp"])
        before := Services.errors
        Check(Services.IgnoreMatch("drop.tmp"), "boot failure preserves ignore behavior")
        Check(Services.tripped && Services.errors == before + 1, "boot failure counted once")
        Check(Services.IgnoreMatch("drop.tmp"), "subsequent fallback still matches")
        Check(Services.errors == before + 1, "missing backend is not retried")
    } catch as err {
        failures++
        FileAppend("FAIL unexpected error: " err.Message "`n" err.Stack "`n", "*", "UTF-8-RAW")
    } finally {
        if HistoryManager.saveTimer
            SetTimer(HistoryManager.saveTimer, 0)
        HistoryManager.savePending := false
        DirDelete(work, true)
    }
    FileAppend(checks " checks, " failures " failures`n", "*", "UTF-8-RAW")
    ExitApp(failures ? 1 : 0)
}

Main()
