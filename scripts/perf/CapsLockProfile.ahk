#Requires AutoHotkey v2.0
#SingleInstance Off

; ---------------------------------------------------------------------------
; Performance baseline for the AHK <-> C# service boundary (issue #12).
;
; Run with:
;     AutoHotkey64.exe /ErrorStdOut scripts\perf\CapsLockProfile.ahk
;
; This is the "establish a reproducible performance baseline" acceptance
; criterion. It loads the project's REAL modules -- not reimplementations --
; and times the exact code paths a migrated service would replace:
;
;     History/HistoryStorage.ahk    HistoryManager.Add / Load / DoSave
;     Core/FileOperations.ahk       FileHelper.ShouldIgnore / CollectFilesFromFolder
;     Utils/Json.ahk                Json.Stringify / Json.Parse
;
; Results go to scripts\perf\results\baseline-<timestamp>.{json,md}.
; The numbers stay blank until someone runs this on real hardware; nothing
; here invents them.
;
; Deliberately NOT measured here
;   * start-up, idle CPU, idle memory and CapsLock -> Send latency: those are
;     whole-process figures and come from
;     scripts\benchmark\Measure-CapsLockBuild.ps1
;   * Smart Paste end to end: it needs a running app and a real target window
;     (also in the PowerShell harness).
;
; Command line
;     -Clipboard        also measure the clipboard round trip. Off by default
;                       because it overwrites the real clipboard.
;     -Out <dir>        write results somewhere else
;     -History <sizes>  comma separated history sizes, default 1000,10000
;     -Files <count>    files per generated directory, default 8
; ---------------------------------------------------------------------------

#Include ..\..\Config\Globals.ahk
#Include ..\..\Config\Encryption.ahk
#Include ..\..\Utils\Json.ahk
#Include ..\..\History\HistoryStorage.ahk
#Include ..\..\Core\FileOperations.ahk
#Include ..\..\Core\Services.ahk

; ---------------------------------------------------------------------------
; Timing
; ---------------------------------------------------------------------------

class Bench {
    static freq := 0

    static Init() {
        f := 0
        DllCall("QueryPerformanceFrequency", "Int64*", &f)
        this.freq := f
    }

    static Now() {
        c := 0
        DllCall("QueryPerformanceCounter", "Int64*", &c)
        return c
    }

    ; Calls "fn" "iterations" times, timing each call, and returns per-call
    ; statistics in milliseconds. Warm-up calls are discarded.
    static Measure(fn, iterations, warmup := 1) {
        loop warmup
            fn()

        samples := []

        loop iterations {
            t0 := this.Now()
            fn()
            t1 := this.Now()
            samples.Push(((t1 - t0) * 1000.0) / this.freq)
        }

        return this.Summarize(samples)
    }

    static Summarize(samples) {
        sorted := this.Sorted(samples)
        total := 0.0

        for value in sorted
            total += value

        n := sorted.Length
        mean := (n > 0) ? (total / n) : 0.0

        return Map(
            "n", n,
            "min_ms", this.Round4(this.Percentile(sorted, 0.0)),
            "p50_ms", this.Round4(this.Percentile(sorted, 0.5)),
            "p95_ms", this.Round4(this.Percentile(sorted, 0.95)),
            "mean_ms", this.Round4(mean),
            "max_ms", this.Round4(this.Percentile(sorted, 1.0)),
            "total_ms", this.Round4(total)
        )
    }

    ; Insertion sort. n is small and this avoids depending on
    ; Array.Prototype.Sort, whose signature moved between AHK v2 alphas.
    static Sorted(samples) {
        out := []

        for value in samples {
            placed := false
            i := 1
            while (i <= out.Length) {
                if (value < out[i]) {
                    out.InsertAt(i, value)
                    placed := true
                    break
                }
                i++
            }
            if !placed
                out.Push(value)
        }

        return out
    }

    static Percentile(sorted, p) {
        n := sorted.Length
        if (n == 0)
            return 0.0

        index := Round((n - 1) * p) + 1
        index := (index < 1) ? 1 : index
        index := (index > n) ? n : index

        return sorted[index]
    }

    static Round4(value) {
        return Round(value, 4)
    }
}

; ---------------------------------------------------------------------------
; Workloads
;
; These are global functions taking one unused argument so they can be handed
; to Bench.Measure through .Bind(). Bound functions, not closures: the
; codebase already uses .Bind() and it avoids depending on how fat arrow
; functions capture locals.
; ---------------------------------------------------------------------------

gPaths := []
gPathIndex := 0
gEnumRoot := ""
gJsonText := ""
gCounter := 0
gRulesText := ""
gTexts := []

WorkloadHistoryAddNew(unused) {
    ; A genuinely new clip: full reverse duplicate scan, InsertAt(1), and a
    ; Pop once MaxHistory is reached. This is the real "copy something" cost.
    global gCounter
    gCounter++
    HistoryManager.Add("bench-unique-" gCounter "-" A_TickCount, "bench")
}

WorkloadHistoryAddDuplicateTop(unused) {
    ; Re-copying the most recent clip: Add() returns after one comparison.
    first := AppState.History[1]["text"]
    HistoryManager.Add(first, "bench")
}

WorkloadHistorySave(unused) {
    ; DoSave() is normally debounced behind a 3 s timer and no-ops unless the
    ; pending flag is set, so the flag is raised directly here.
    HistoryManager.savePending := true
    HistoryManager.DoSave()
}

WorkloadHistoryLoad(unused) {
    HistoryManager.Load()
}

WorkloadIgnoreNext(unused) {
    global gPaths, gPathIndex
    gPathIndex++
    if (gPathIndex > gPaths.Length)
        gPathIndex := 1
    FileHelper.ShouldIgnore(gPaths[gPathIndex])
}

WorkloadIgnoreBuild(unused) {
    FileHelper.BuildIgnoreRegexes()
}

WorkloadEnumTree(unused) {
    FileHelper.CollectFilesFromFolder(gEnumRoot, true)
}

WorkloadJsonRoundTrip(unused) {
    global gJsonText
    gJsonText := Json.Stringify(AppState.History)
    parsed := Json.Parse(gJsonText)
}

WorkloadClipboardRoundTrip(unused) {
    global gCounter
    gCounter++
    A_Clipboard := "bench clipboard payload " gCounter
    return A_Clipboard
}

; --- AHK vs C# on identical workloads --------------------------------------
;
; The C# halves are reached through Core\Services.ahk, which is disabled by
; default and only turns on when [Services] Backend=csharp is set and AHK# is
; installed. These run the same inputs through both halves so the comparison
; is apples to apples.

WorkloadIgnoreMatchCSharp(unused) {
    global gPaths, gPathIndex, gRulesText
    gPathIndex++
    if (gPathIndex > gPaths.Length)
        gPathIndex := 1
    Services.IgnoreMatch(gPaths[gPathIndex], gRulesText)
}

WorkloadIgnoreMatchAhk(unused) {
    global gPaths, gPathIndex
    gPathIndex++
    if (gPathIndex > gPaths.Length)
        gPathIndex := 1
    FileHelper.ShouldIgnore(gPaths[gPathIndex])
}

; NOTE: this is the NAIVE boundary. The whole array crosses into .NET on every
; call, so the number includes marshalling that a real migration would avoid by
; keeping the history resident on the C# side. Read it as a worst case, not as
; what a finished HistoryService would cost.
WorkloadHistoryScanCSharp(unused) {
    global gTexts
    Services.HistoryFindDuplicate(gTexts, "__bench_absent__")
}

WorkloadHistoryScanAhk(unused) {
    global gTexts
    ServicesHistoryFindDuplicateAhk(gTexts, "__bench_absent__")
}

; ---------------------------------------------------------------------------
; Corpus
; ---------------------------------------------------------------------------

BuildFileTree(root, depth, dirsPerLevel, filesPerDir) {
    DirCreate(root)

    if (depth == 0)
        return

    loop dirsPerLevel {
        child := root "\dir" A_Index
        DirCreate(child)

        loop filesPerDir {
            FileAppend("bench", child "\file" A_Index ".txt")
            if (Mod(A_Index, 4) == 0)
                FileAppend("bench", child "\cache" A_Index ".tmp")
            if (Mod(A_Index, 7) == 0)
                FileAppend("bench", child "\debug" A_Index ".log")
        }

        BuildFileTree(child, depth - 1, dirsPerLevel, filesPerDir)
    }
}

CollectTree(root) {
    paths := []

    loop files, root "\*", "FR"
        paths.Push(A_LoopFileFullPath)

    return paths
}

FillHistory(count) {
    AppState.History := []
    AppState.MaxHistory := count
    AppState.IgnoreNextClipChange := false

    loop count {
        text := "history entry " A_Index " with a representative length so the buffer is not trivial"
        AppState.History.Push(Map("time", "2026-01-01 00:00:00", "source", "bench", "text", text))
    }
}

; Returns true when the C# backend can actually be driven from this run.
; Turns the backend on for the process; nothing else in the app is affected
; because this script never registers a hotkey.
TryEnableBackend() {
    try {
        AppState.ServiceBackend := "csharp"
        Services.Configure()
        return Services.Boot()
    } catch as err {
        return false
    }
}

JoinRules(rules) {
    text := ""
    for index, rule in rules
        text .= (index > 1 ? "`n" : "") . rule
    return text
}

HistoryTexts() {
    texts := []
    for item in AppState.History
        texts.Push(item["text"])
    return texts
}

RealisticIgnoreRules() {
    ; A mix of the two code paths in ShouldIgnore: simple globs answered by
    ; PathMatchSpecW, and gitignore-style patterns that fall back to regex.
    return [
        "*.tmp",
        "*.log",
        "Thumbs.db",
        "?emp*",
        "build/**",
        "**/obj/**",
        "**/.git/**",
        "**/node_modules/**",
        "dir1/**/*.txt"
    ]
}

; ---------------------------------------------------------------------------
; Reporting
; ---------------------------------------------------------------------------

Say(text) {
    try
        FileAppend(text . "`n", "*")
    catch {
        ; stdout is unavailable when the script is launched through /Validate
    }
}

FormatRow(label, stats) {
    return Format("    {1,-36} p50 {2} ms   p95 {3} ms   min {4} ms   max {5} ms   n={6}",
        label, stats["p50_ms"], stats["p95_ms"], stats["min_ms"], stats["max_ms"], stats["n"])
}

BuildMarkdown(environment, results) {
    lines := []
    lines.Push("## Baseline run " environment["generated"])
    lines.Push("")
    lines.Push("| | |")
    lines.Push("| :-- | :-- |")
    lines.Push("| AutoHotkey | " environment["ahk_version"] " (" environment["ahk_bitness"] ") |")
    lines.Push("| OS | " environment["os"] " |")
    lines.Push("| Processors | " environment["processors"] " |")
    lines.Push("| Machine | " environment["computer"] " |")
    lines.Push("| File corpus | " environment["file_count"] " files |")
    lines.Push("| Ignore rules | " environment["ignore_rules"] " |")
    lines.Push("")
    lines.Push("| benchmark | n | p50 (ms) | p95 (ms) | min (ms) | max (ms) |")
    lines.Push("| :-- | --: | --: | --: | --: | --: |")

    for key, value in results {
        if !IsObject(value)
            continue
        lines.Push(Format("| {1} | {2} | {3} | {4} | {5} | {6} |",
            key, value["n"], value["p50_ms"], value["p95_ms"], value["min_ms"], value["max_ms"]))
    }

    lines.Push("")

    text := ""
    for index, line in lines
        text .= line . "`n"

    return text
}

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------

Main() {
    global gEnumRoot, gPaths, gRulesText, gTexts

    Bench.Init()

    ; --- command line -------------------------------------------------------
    measureClipboard := false
    outDir := A_ScriptDir "\results"
    sizes := [1000, 10000]
    filesPerDir := 8

    args := A_Args
    i := 1
    while (i <= args.Length) {
        switch args[i] {
            case "-Clipboard":
                measureClipboard := true
            case "-Out":
                i++
                if (i <= args.Length)
                    outDir := args[i]
            case "-History":
                i++
                if (i <= args.Length) {
                    sizes := []
                    for part in StrSplit(args[i], ",")
                        sizes.Push(Integer(Trim(part)))
                }
            case "-Files":
                i++
                if (i <= args.Length)
                    filesPerDir := Integer(args[i])
            default:
        }
        i++
    }

    ; --- workspace ----------------------------------------------------------
    work := A_Temp "\CapsLockProfile"
    if DirExist(work)
        DirDelete(work, true)
    DirCreate(work)

    AppState.HistoryFile := work "\ClipHistory.bin"
    AppState.History := []

    Say("Building the file corpus in " work " ...")
    BuildFileTree(work "\tree", 3, 4, filesPerDir)

    gEnumRoot := work "\tree"
    gPaths := CollectTree(gEnumRoot)
    gPathIndex := 0

    AppState.IgnorePatterns := RealisticIgnoreRules()
    FileHelper.BuildIgnoreRegexes()

    Say("    " gPaths.Length " files, " AppState.IgnorePatterns.Length " ignore rules")
    Say("")

    ; --- environment --------------------------------------------------------
    environment := Map(
        "generated", FormatTime(, "yyyy-MM-dd HH:mm:ss"),
        "ahk_version", A_AhkVersion,
        "ahk_bitness", (A_PtrSize == 8) ? "64-bit" : "32-bit",
        "os", A_OSVersion,
        "is_64bit_os", A_Is64bitOS ? "yes" : "no",
        "processors", EnvGet("NUMBER_OF_PROCESSORS"),
        "computer", EnvGet("COMPUTERNAME"),
        "script", A_ScriptFullPath,
        "workspace", work,
        "file_count", gPaths.Length,
        "ignore_rules", AppState.IgnorePatterns.Length,
        "service_backend", AppState.ServiceBackend
    )

    report := Map()
    results := Map()

    ; --- history ------------------------------------------------------------
    for size in sizes {
        Say("History at " size " entries ...")
        FillHistory(size)

        label := "history-add-new-" size
        results[label] := Bench.Measure(WorkloadHistoryAddNew.Bind(0), 200, 5)
        Say(FormatRow(label, results[label]))

        label := "history-add-duplicate-top-" size
        results[label] := Bench.Measure(WorkloadHistoryAddDuplicateTop.Bind(0), 200, 5)
        Say(FormatRow(label, results[label]))

        label := "history-save-" size
        results[label] := Bench.Measure(WorkloadHistorySave.Bind(0), 25, 2)
        Say(FormatRow(label, results[label]))

        label := "history-load-" size
        results[label] := Bench.Measure(WorkloadHistoryLoad.Bind(0), 25, 2)
        Say(FormatRow(label, results[label]))

        label := "json-roundtrip-" size
        results[label] := Bench.Measure(WorkloadJsonRoundTrip.Bind(0), 10, 1)
        Say(FormatRow(label, results[label]))

        Say("")
    }

    ; --- ignore matching ----------------------------------------------------
    Say("Ignore matching ...")

    label := "ignore-shouldignore"
    results[label] := Bench.Measure(WorkloadIgnoreNext.Bind(0), 2000, 50)
    Say(FormatRow(label, results[label]))

    label := "ignore-build-patterns"
    results[label] := Bench.Measure(WorkloadIgnoreBuild.Bind(0), 200, 5)
    Say(FormatRow(label, results[label]))

    Say("")

    ; --- file enumeration ---------------------------------------------------
    Say("File enumeration ...")

    label := "file-enum-recursive-with-ignore"
    results[label] := Bench.Measure(WorkloadEnumTree.Bind(0), 15, 2)
    Say(FormatRow(label, results[label]))

    ; The same walk with no rules, to separate the directory walk from the
    ; per-path ignore matching.
    saved := AppState.IgnorePatterns
    AppState.IgnorePatterns := []
    FileHelper.BuildIgnoreRegexes()

    label := "file-enum-recursive-no-ignore"
    results[label] := Bench.Measure(WorkloadEnumTree.Bind(0), 15, 2)
    Say(FormatRow(label, results[label]))

    AppState.IgnorePatterns := saved
    FileHelper.BuildIgnoreRegexes()

    Say("")

    ; --- clipboard ----------------------------------------------------------
    if measureClipboard {
        Say("Clipboard round trip ...")
        label := "clipboard-text-roundtrip"
        results[label] := Bench.Measure(WorkloadClipboardRoundTrip.Bind(0), 100, 5)
        Say(FormatRow(label, results[label]))
        Say("")
    } else {
        Say("Clipboard round trip skipped. Pass -Clipboard to include it; it overwrites the real clipboard.")
        Say("")
        results["clipboard-text-roundtrip"] := "skipped: run with -Clipboard"
    }

    ; --- backend comparison -------------------------------------------------
    Say("Backend comparison, AutoHotkey vs C# ...")

    gRulesText := JoinRules(AppState.IgnorePatterns)
    gTexts := HistoryTexts()

    if TryEnableBackend() {
        Say("    C# backend: " Services.reason)

        label := "compare-ignore-match-csharp"
        results[label] := Bench.Measure(WorkloadIgnoreMatchCSharp.Bind(0), 2000, 50)
        Say(FormatRow(label, results[label]))

        label := "compare-history-scan-csharp-naive"
        results[label] := Bench.Measure(WorkloadHistoryScanCSharp.Bind(0), 200, 10)
        Say(FormatRow(label, results[label]))

        ; Same inputs, AutoHotkey side, measured in the same run so the machine
        ; state is identical.
        label := "compare-ignore-match-ahk"
        results[label] := Bench.Measure(WorkloadIgnoreMatchAhk.Bind(0), 2000, 50)
        Say(FormatRow(label, results[label]))

        label := "compare-history-scan-ahk"
        results[label] := Bench.Measure(WorkloadHistoryScanAhk.Bind(0), 200, 10)
        Say(FormatRow(label, results[label]))

        report["services"] := Services.Status()
    } else {
        Say("    C# backend unavailable: " Services.reason)
        Say("    See docs/perf/csharp-boundary.md: AHK# is not vendored and the")
        Say("    assembly has to be built before this comparison can run.")
        results["compare-ignore-match-csharp"] := "skipped: C# backend unavailable"
        results["compare-history-scan-csharp-naive"] := "skipped: C# backend unavailable"
        results["compare-ignore-match-ahk"] := "skipped: C# backend unavailable"
        results["compare-history-scan-ahk"] := "skipped: C# backend unavailable"
        report["services"] := Services.Status()
    }

    Say("")

    ; --- output -------------------------------------------------------------
    if !DirExist(outDir)
        DirCreate(outDir)

    stamp := FormatTime(, "yyyyMMdd-HHmmss")
    jsonPath := outDir "\baseline-" stamp ".json"
    mdPath := outDir "\baseline-" stamp ".md"

    report["environment"] := environment
    report["results"] := results

    if FileExist(jsonPath)
        FileDelete(jsonPath)
    FileAppend(Json.Stringify(report, true), jsonPath, "UTF-8")

    if FileExist(mdPath)
        FileDelete(mdPath)
    FileAppend(BuildMarkdown(environment, results), mdPath, "UTF-8")

    Say("wrote " jsonPath)
    Say("wrote " mdPath)
    Say("")
    Say("Paste these into docs/perf/csharp-boundary.md. Do not adjust them.")

    if DirExist(work)
        DirDelete(work, true)

    ExitApp(0)
}

Main()
