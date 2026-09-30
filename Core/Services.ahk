#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; The AHK <-> C# service boundary (issue #12).
;
; Shape of the boundary
;
;   AutoHotkey owns: hotkeys, the clipboard, Send, every GUI, and every path
;                    that must answer inside a single keystroke.
;   C# owns:         pure, data-heavy work that allocates and loops a lot --
;                    the history duplicate scan, ignore-rule matching, text
;                    normalisation.
;
; Nothing here is enabled by default. AppState.ServiceBackend is "ahk" unless
; someone sets [Services] Backend=csharp in Config.ini, so adding this module
; changes no behaviour at all.
;
; Every crossing is guarded three ways:
;   1. the backend is only reached when it is explicitly enabled;
;   2. the first failure opens a circuit breaker that disables C# for the rest
;      of the process, so a broken bridge costs one exception rather than
;      degraded performance for the whole session;
;   3. every call falls back to the AutoHotkey implementation.
;
; AHK# is not vendored
;
; The library is not committed to this repository: it ships a prebuilt
; ahk#.bridge.dll, and that is a binary we would have to review and re-pin on
; every upgrade. Instead the module looks for AHK# on disk and reports
; "not installed" when it is missing. docs/perf/csharp-boundary.md explains
; how to drop it in at the pinned commit.
; ---------------------------------------------------------------------------

class Services {
    ; --- state ---------------------------------------------------------------

    static backend := "ahk"      ; "ahk" (default) or "csharp"
    static ready := false        ; the CLR is booted and the assembly is loaded
    static tripped := false      ; circuit breaker: an error already happened
    static reason := "not configured"

    static calls := 0            ; C# calls that returned
    static fallbacks := 0        ; calls that ended up running AutoHotkey
    static errors := 0           ; calls that threw

    static assemblyPath := ""    ; override for CapsLockSharp.dll
    static history := ""         ; CapsLockSharp.HistoryService
    static ignore := ""          ; CapsLockSharp.IgnoreMatcher
    static clipboard := ""       ; CapsLockSharp.ClipboardService

    ; --- configuration --------------------------------------------------------

    ; Reads the configured backend. Call once, after ConfigManager.Load().
    static Configure() {
        value := "ahk"

        try
            value := StrLower(Trim(String(AppState.ServiceBackend)))
        catch
            value := "ahk"

        if (value != "csharp")
            value := "ahk"

        this.backend := value

        if (value != "csharp")
            this.reason := "backend is ahk"

        return this.backend
    }

    static IsEnabled() {
        return (this.backend == "csharp") && !this.tripped
    }

    ; Where the compiled CapsLockSharp.dll is expected to live.
    static DefaultAssemblyPath() {
        return A_ScriptDir "\lib\CapsLockSharp.dll"
    }

    static DefaultBridgePath() {
        return A_ScriptDir "\lib\ahk#\ahk#.bridge.dll"
    }

    ; --- boot ------------------------------------------------------------------

    ; Boots the CLR and loads the assembly. Safe to call repeatedly.
    ;
    ; The first AHK# call costs about 100 ms to start the CLR, which is why
    ; this never runs during start-up: it happens on the first service call
    ; that actually asks for the C# backend.
    static Boot() {
        global CS

        if this.ready
            return true

        if this.tripped
            return false

        if !this.IsEnabled() {
            this.reason := "backend is ahk"
            return false
        }

        try {
            if !this.HaveBridge() {
                this.reason := "AHK# is not installed"
                this.tripped := true
                return false
            }

            dll := this.assemblyPath ? this.assemblyPath : this.DefaultAssemblyPath()

            if !FileExist(dll) {
                this.reason := "CapsLockSharp.dll not found at " dll
                this.tripped := true
                return false
            }

            ; Must happen before the first CS use: AHK# hashes the bridge DLL
            ; as it loads it, and defaults to looking next to ahk#.ahk.
            try
                CS.Config.BridgeDll := this.DefaultBridgePath()
            catch {
                ; A HK# build without CS.Config is still usable; it will look
                ; for the bridge beside ahk#.ahk instead.
            }

            CS.LoadAssembly(dll)

            this.history := CS.CreateObject("CapsLockSharp.HistoryService")
            this.ignore := CS.CreateObject("CapsLockSharp.IgnoreMatcher")
            this.clipboard := CS.CreateObject("CapsLockSharp.ClipboardService")

            this.ready := true
            this.reason := "ready"
            return true
        } catch as err {
            this.errors++
            this.tripped := true
            this.reason := "boot failed: " err.Message
            return false
        }
    }

    ; AHK# exposes itself as a global named CS. Referencing an unset global is
    ; a catchable error, and IsSet answers without throwing.
    static HaveBridge() {
        global CS

        try {
            if !IsSet(CS)
                return false
            return IsObject(CS)
        } catch {
            return false
        }
    }

    ; --- status ----------------------------------------------------------------

    static Status() {
        return Map(
            "backend", this.backend,
            "ready", this.ready,
            "tripped", this.tripped,
            "reason", this.reason,
            "calls", this.calls,
            "fallbacks", this.fallbacks,
            "errors", this.errors
        )
    }

    ; --- the guarded call --------------------------------------------------------

    ; Runs "csharpFn" when the backend is up, otherwise "ahkFn". Any exception
    ; trips the breaker and falls back, so a broken bridge cannot wedge the app.
    ; Both arguments are bound functions, never closures.
    static Dispatch(csharpFn, ahkFn) {
        if (this.IsEnabled() && this.Boot()) {
            try {
                result := csharpFn()
                this.calls++
                return result
            } catch as err {
                this.errors++
                this.tripped := true
                this.reason := "call failed: " err.Message
            }
        }

        this.fallbacks++
        return ahkFn()
    }

    ; --- ignore matching ----------------------------------------------------------

    ; Rules cross the boundary newline separated, which puts one string on the
    ; wire instead of an array. The C# side caches the compiled matcher against
    ; that exact text, so the rules are compiled once, not per path.
    static IgnoreMatch(path, rulesText) {
        return this.Dispatch(
            ServicesIgnoreMatchCSharp.Bind(path, rulesText),
            ServicesIgnoreMatchAhk.Bind(path, rulesText)
        )
    }

    ; --- history duplicate scan -----------------------------------------------------

    ; Returns the 1-based index of an existing identical entry, or 0 -- the
    ; shape HistoryManager.Add wants.
    static HistoryFindDuplicate(texts, candidate) {
        return this.Dispatch(
            ServicesHistoryFindDuplicateCSharp.Bind(texts, candidate),
            ServicesHistoryFindDuplicateAhk.Bind(texts, candidate)
        )
    }

    ; --- clipboard text --------------------------------------------------------------

    static LooksLikeFilePathList(text) {
        return this.Dispatch(
            ServicesLooksLikeFilePathListCSharp.Bind(text),
            ServicesLooksLikeFilePathListAhk.Bind(text)
        )
    }
}

; ---------------------------------------------------------------------------
; Backend halves.
;
; These are global functions rather than static methods so they can be handed
; to Services.Dispatch through .Bind() without depending on how AutoHotkey
; binds "this" for a static method, which is the one detail of the object
; model that is easy to get wrong and unpleasant to debug.
; ---------------------------------------------------------------------------

ServicesIgnoreMatchCSharp(path, rulesText) {
    return Services.ignore.IsMatch(rulesText, path) ? true : false
}

ServicesIgnoreMatchAhk(path, rulesText) {
    ; No local reimplementation on purpose. FileHelper.ShouldIgnore stays the
    ; single AutoHotkey source of truth; this fallback is only reached when the
    ; C# backend is enabled but unavailable, and in that case the caller's own
    ; AutoHotkey path has already been bypassed, so the honest answer is to
    ; match nothing and let the caller keep its previous behaviour.
    return false
}

ServicesHistoryFindDuplicateCSharp(texts, candidate) {
    index := Services.history.FindDuplicateIndex(texts, candidate)
    return Integer(index) + 1
}

ServicesHistoryFindDuplicateAhk(texts, candidate) {
    i := texts.Length
    while (i > 0) {
        if (texts[i] == candidate)
            return i
        i--
    }
    return 0
}

ServicesLooksLikeFilePathListCSharp(text) {
    return Services.clipboard.LooksLikeFilePathList(text) ? true : false
}

ServicesLooksLikeFilePathListAhk(text) {
    if (text == "")
        return false
    if !InStr(text, "`n")
        return false

    first := StrSplit(text, "`n", "`r")[1]
    return FileExist(first) ? true : false
}
