#Requires AutoHotkey v2.0
#SingleInstance Off

; ---------------------------------------------------------------------------
; Headless regression checks for CapsLock Extended.
;
; Run with (AutoHotkey is a GUI program: a plain console launch neither waits
; for it, shows its output nor reports its exit code, so use the wrapper):
;     .\scripts\ci\Invoke-Ahk.ps1 .\scripts\HotkeyRegression.ahk
;
; The script exits with 0 when every check passes and with 1 when at least one
; fails, so it works as a CI gate. It never opens a window, never registers a
; hotkey and never loads CapsLock-.ahk: every check reads and cross-references
; the sources, which keeps the run fast and side-effect free on a build agent.
;
; Checks
;   1. every #Include target resolves to an existing file
;   2. every FileInstall source exists
;   3. lang.csv is well formed: uniform column count, unique non-empty keys
;   4. every literal Lang("KEY") used in the sources exists in lang.csv
;   5. every documented shortcut in Hotkeys\HotkeyReference.ahk has a matching
;      binding in Hotkeys\HotkeyBindings.ahk
;   6. every setting ConfigManager loads is also saved, and vice versa
;   7. every source file under the project folders is #Included somewhere
;
; Deliberately not covered
;   * language keys that are composed at run time, for example
;     Lang("MENU_WS_DENSITY_" . StrUpper(mode), mode). They cannot be resolved
;     without executing the code, so they are skipped rather than guessed.
; ---------------------------------------------------------------------------

global gChecks := 0
global gFailures := []

; The application's own source folders. Only these (plus CapsLock-.ahk) are
; scanned: the repository root can also hold test scripts and the AutoHotkey
; runtime unpacked by CI, which are not application modules.
global gSourceFolders := ["Config", "Core", "Hotkeys", "History", "Tray", "UI", "Utils"]

; ---------------------------------------------------------------------------
; Framework
; ---------------------------------------------------------------------------

Check(condition, name, detail := "") {
    global gChecks, gFailures
    gChecks++

    if !condition {
        gFailures.Push({ name: name, detail: detail })
        Say("FAIL  " name . (detail != "" ? "  --  " detail : ""))
    }
}

Say(text) {
    try
        FileAppend(text . "`n", "*", "UTF-8-RAW")
    catch {
        ; stdout is unavailable when the script is launched through /Validate
    }
}

RepoRoot() {
    ; A_ScriptDir is <repo>\scripts when this file runs from the checkout.
    dir := RTrim(A_ScriptDir, "\")
    cut := InStr(dir, "\", , -1)
    return cut ? SubStr(dir, 1, cut - 1) : dir
}

ReadText(path) {
    try
        return FileRead(path, "UTF-8")
    catch
        return ""
}

; Returns an array of { pos, len, groups } for every match in "haystack".
; Callers read groups[1], so every needle needs at least one capture group.
AllMatches(haystack, needle) {
    result := []
    position := 1

    loop {
        found := RegExMatch(haystack, needle, &m, position)
        if !found
            break

        groups := []
        loop m.Count
            groups.Push(m[A_Index])

        result.Push({ pos: m.Pos, len: m.Len, groups: groups })
        ; Always advance: an empty match must not be found again at the same spot.
        position := m.Pos + Max(m.Len, 1)
    }

    return result
}

; Split a logical line on top-level commas, ignoring commas inside quotes and
; inside nested parentheses. Used both for CSV rows and for call arguments.
SplitArguments(text) {
    parts := []
    current := ""
    inQuotes := false
    depth := 0

    for index, ch in StrSplit(text) {
        if ch == '"'
            inQuotes := !inQuotes

        if !inQuotes {
            if ch == "("
                depth++
            else if ch == ")"
                depth--
            else if (ch == "," && depth == 0) {
                parts.Push(Trim(current))
                current := ""
                continue
            }
        }

        current .= ch
    }

    parts.Push(Trim(current))
    return parts
}

Unquote(text) {
    text := Trim(text)
    if (StrLen(text) >= 2 && SubStr(text, 1, 1) == '"' && SubStr(text, -1) == '"')
        text := SubStr(text, 2, StrLen(text) - 2)
    return text
}

JoinList(items) {
    text := ""
    for index, item in items
        text .= (index > 1 ? ", " : "") . item
    return text
}

; ---------------------------------------------------------------------------
; 1 + 2: #Include and FileInstall targets
; ---------------------------------------------------------------------------

CheckIncludes(root, files) {
    for path in files {
        relative := StrReplace(path, root "\", "")
        SplitPath(path, , &directory)

        ; Relative #Include paths resolve against the including file's folder.
        for match in AllMatches(ReadText(path), "m)^[ \t]*#Include[ \t]+`"([^`"]+)`"[ \t]*$") {
            target := match.groups[1]
            Check(FileExist(directory "\" target),
            "include resolves: " target,
            "referenced from " relative)
        }
    }
}

CheckFileInstalls(root, files) {
    for path in files {
        relative := StrReplace(path, root "\", "")

        for match in AllMatches(ReadText(path), "FileInstall\([ \t]*`"([^`"]+)`"") {
            target := match.groups[1]
            Check(FileExist(root "\" target),
            "FileInstall source exists: " target,
            "referenced from " relative)
        }
    }
}

; ---------------------------------------------------------------------------
; 3: lang.csv structure
; ---------------------------------------------------------------------------

LoadLanguageKeys(root) {
    csvPath := root "\lang.csv"

    if !FileExist(csvPath) {
        Check(false, "lang.csv exists", csvPath)
        return Map()
    }

    Check(true, "lang.csv exists")

    raw := ReadText(csvPath)
    if (SubStr(raw, 1, 1) == Chr(0xFEFF))
        raw := SubStr(raw, 2)

    lines := StrSplit(raw, "`n", "`r")
    expectedColumns := 0
    keys := Map()
    duplicates := []
    rowNumber := 0

    for index, line in lines {
        if (Trim(line) == "")
            continue

        rowNumber++
        columns := SplitArguments(line)

        if (rowNumber == 1) {
            expectedColumns := columns.Length
            Check(expectedColumns > 1, "lang.csv header declares language columns", line)
            Check(Trim(columns[1]) == "key", "lang.csv first column is 'key'", line)
            continue
        }

        if (columns.Length != expectedColumns) {
            Check(false,
                "lang.csv row has " expectedColumns " columns",
                "line " index " has " columns.Length " -- " SubStr(line, 1, 60))
            continue
        }

        key := Trim(columns[1])

        if (key == "") {
            Check(false, "lang.csv row has an empty key", "line " index)
            continue
        }

        if keys.Has(key) {
            duplicates.Push(key)
            continue
        }

        keys[key] := true
    }

    Check(rowNumber > 1, "lang.csv contains data rows", "rows: " (rowNumber - 1))
    Check(duplicates.Length == 0,
        "lang.csv has no duplicate keys",
        duplicates.Length ? "duplicates: " JoinList(duplicates) : "")

    return keys
}

; ---------------------------------------------------------------------------
; 4: Lang() keys
; ---------------------------------------------------------------------------

CheckLanguageKeys(root, files, languageKeys) {
    if (languageKeys.Count == 0)
        return

    missing := Map()
    padding := Map()

    for path in files {
        source := ReadText(path)
        relative := StrReplace(path, root "\", "")

        ; A key with leading or trailing whitespace never resolves, so Lang()
        ; falls back and the user sees the raw key.
        for match in AllMatches(source, "Lang\([ \t]*`"([ \t]+[A-Z0-9_]*[A-Z][A-Z0-9_]*[ \t]*|[A-Z0-9_]*[A-Z][A-Z0-9_]*[ \t]+)`"")
            padding["'" match.groups[1] "'"] := relative

        for match in AllMatches(source, "Lang\([ \t]*`"([A-Z][A-Z0-9_]*)`"[ \t]*([,)])") {
            key := match.groups[1]
            if !languageKeys.Has(key)
                missing[key] := relative
        }
    }

    missingList := []
    for key, relative in missing
        missingList.Push(key)

    Check(missingList.Length == 0,
        "every Lang() key exists in lang.csv",
        missingList.Length ? "missing: " JoinList(missingList) : "")

    paddingList := []
    for key, relative in padding
        paddingList.Push(key . " (" relative ")")

    Check(paddingList.Length == 0,
        "Lang() keys carry no stray whitespace",
        paddingList.Length ? "padded: " JoinList(paddingList) : "")
}

; ---------------------------------------------------------------------------
; 5: documented shortcuts vs. real bindings
; ---------------------------------------------------------------------------

CheckShortcutBindings(root) {
    bindingsPath := root "\Hotkeys\HotkeyBindings.ahk"
    referencePath := root "\Hotkeys\HotkeyReference.ahk"

    if !FileExist(bindingsPath) {
        Check(false, "Hotkeys\HotkeyBindings.ahk exists")
        return
    }
    if !FileExist(referencePath) {
        Check(false, "Hotkeys\HotkeyReference.ahk exists")
        return
    }

    bound := Map()

    for match in AllMatches(ReadText(bindingsPath),
    "m)^[ \t]*([~*$]*[\^!+#]*[A-Za-z0-9]+)[ \t]*(?:up)?[ \t]*::") {
        bound[NormalizeKeyName(match.groups[1])] := true
    }

    Check(bound.Count > 0, "hotkey bindings were parsed", "found " bound.Count)

    for match in AllMatches(ReadText(referencePath), "keys:[ \t]*`"([^`"]+)`"")
        CheckShortcut(bound, match.groups[1])
}

CheckShortcut(bound, display) {
    text := display
    text := StrReplace(text, "Middle Button", "MButton")
    text := StrReplace(text, "Left Button", "LButton")
    text := StrReplace(text, "Right Button", "RButton")
    text := StrReplace(text, "←", "Left")
    text := StrReplace(text, "→", "Right")
    text := StrReplace(text, "↑", "Up")
    text := StrReplace(text, "↓", "Down")
    text := StrReplace(text, "Num8", "Numpad8")
    text := StrReplace(text, "Num2", "Numpad2")

    matched := false

    for match in AllMatches(text, "([A-Za-z0-9]+)") {
        if bound.Has(NormalizeKeyName(match.groups[1]))
            matched := true
    }

    Check(matched, "documented shortcut is bound: " display)
}

; Strip the modifier prefixes and fold the case: AHK spells the mouse buttons
; MButton / LButton / RButton and key names are case insensitive.
NormalizeKeyName(name) {
    for prefix in ["~", "*", "$", "^", "!", "+", "#"]
        name := StrReplace(name, prefix, "")
    return StrLower(Trim(name))
}

; ---------------------------------------------------------------------------
; 6: ConfigManager read / write symmetry
; ---------------------------------------------------------------------------

CheckConfigRoundTrip(root) {
    path := root "\Config\ConfigManager.ahk"

    if !FileExist(path) {
        Check(false, "Config\ConfigManager.ahk exists")
        return
    }

    source := ReadText(path)
    loadStart := InStr(source, "static Load()")
    saveStart := InStr(source, "static Save(")

    if (!loadStart || !saveStart) {
        Check(false, "ConfigManager defines Load() and Save()")
        return
    }

    loadSection := SubStr(source, loadStart, saveStart - loadStart)
    saveSection := SubStr(source, saveStart)

    read := CollectIniPairs(loadSection, "Read")
    write := CollectIniPairs(saveSection, "Write")

    Check(read.Count > 0, "ConfigManager loads settings", "found " read.Count)
    Check(write.Count > 0, "ConfigManager saves settings", "found " write.Count)

    missing := []
    for pair, _ in read {
        if !write.Has(pair)
            missing.Push(pair)
    }

    Check(missing.Length == 0,
        "every setting that is loaded is also saved",
        missing.Length ? "loaded but never saved: " JoinList(missing) : "")

    extra := []
    for pair, _ in write {
        if !read.Has(pair)
            extra.Push(pair)
    }

    Check(extra.Length == 0,
        "every setting that is saved is also loaded",
        extra.Length ? "saved but never loaded: " JoinList(extra) : "")
}

; Returns a Map of "section|key" -> true for every IniRead / IniWrite call in
; "text". The two functions take their arguments in a different order:
;     IniRead(Filename, Section, Key, Default)
;     IniWrite(Value, Filename, Section, Key)
CollectIniPairs(text, kind) {
    pairs := Map()

    for match in AllMatches(text, "(Ini" kind "\()") {
        start := match.pos + match.len
        closing := FindClosingParen(text, start)

        if !closing
            continue

        args := SplitArguments(SubStr(text, start, closing - start))

        if (kind == "Read" && args.Length >= 3)
            pairs[Unquote(args[2]) "|" Unquote(args[3])] := true
        else if (kind == "Write" && args.Length >= 4)
            pairs[Unquote(args[3]) "|" Unquote(args[4])] := true
    }

    return pairs
}

; Returns the index just past the ")" that closes the call opened before
; "start", or 0 when the text ends first.
FindClosingParen(text, start) {
    depth := 1
    index := start

    while (index <= StrLen(text)) {
        ch := SubStr(text, index, 1)

        if (ch == "(")
            depth++
        else if (ch == ")") {
            depth--
            if (depth == 0)
                return index
        }

        index++
    }

    return 0
}

; ---------------------------------------------------------------------------
; Focused regressions for the window badge, tray callback, shift-layer toast,
; and theme boundary
; ---------------------------------------------------------------------------

CheckPinIndicatorRegressions(root) {
    pinText := ReadText(root "\UI\PinIndicator.ahk")
    trayText := ReadText(root "\Tray\TrayMenu.ahk")

    Check(
        InStr(trayText, "callback: PinIndicator.MakeUnpinCallback(hwnd)") > 0
            && InStr(pinText, "static MakeUnpinCallback(hwnd)") > 0
            && InStr(pinText, "=> PinIndicator.UnpinFromMenu(hwnd)") > 0,
        "tray unpin callback captures its HWND without relying on event parameters"
    )

    updateStart := InStr(pinText, "static _UpdateBadge(hwnd)")
    minimizedAt := updateStart ? InStr(pinText, "minimized := WinGetMinMax", false, updateStart) : 0
    topmostAt := updateStart ? InStr(pinText, "if !this.IsTopmost(hwnd)", false, updateStart) : 0
    Check(
        updateStart && minimizedAt && topmostAt && minimizedAt < topmostAt,
        "minimized pinned windows remain tracked until restore"
    )
    Check(
        InStr(pinText, "IsWindowVisible") > 0 && InStr(pinText, "NoActivate") > 0,
        "pin badge visibility is reconciled with the native window after restore"
    )
    Check(
        InStr(pinText, "static UpdateInterval := 16") > 0
            && InStr(pinText, "state.wasMinimized := true") > 0
            && InStr(pinText, "static _EnsureBadgeWindow(hwnd, forceRecreate := false)") > 0
            && InStr(pinText, "_EnsureBadgeWindow(hwnd, state.wasMinimized)") > 0
            && InStr(pinText, "+Owner") == 0,
        "pin badge follows rapid movement and cannot be hidden with its owner during restore"
    )
}

CheckShiftLayerToastRegressions(root) {
    actionText := ReadText(root "\Hotkeys\HotkeyActions.ahk")
    osdText := ReadText(root "\UI\OSD.ahk")

    Check(
        InStr(actionText, "ShiftLayerToast.Show(duration") > 0
            && InStr(actionText, "ShiftLayerToast.Hide()") > 0
            && InStr(osdText, "class ShiftLayerToast") > 0
            && InStr(osdText, "remainingWidth := Max(1, Round(this.Width * remaining / this.Duration))") > 0,
        "Shift-layer activation shows a timed top-edge progress bar"
    )
}

CheckThemeTokenArchitecture(root) {
    themeText := ReadText(root "\UI\Theme.ahk")
    helperText := ReadText(root "\UI\ThemeHelper.ahk")
    settingsText := ReadText(root "\UI\SettingsGui.ahk")
    stateText := ReadText(root "\Config\Globals.ahk")

    Check(
        InStr(themeText, "static Palettes := Map(") > 0
            && InStr(themeText, "PrimaryContainer") > 0
            && InStr(themeText, "TextSecondary") > 0,
        "theme exposes shared semantic surface and text roles"
    )
    Check(
        InStr(settingsText, "ThemeHelper.AddSurfaceCard") > 0
            && InStr(settingsText, "nav-active") > 0
            && InStr(helperText, "CreateRoundRectRgn") > 0,
        "settings pages use shared rounded surfaces and navigation components"
    )
    Check(
        InStr(stateText, "THEME_") == 0,
        "presentation tokens stay out of persisted application state"
    )
}

; ---------------------------------------------------------------------------
; 7: every source file is reachable
; ---------------------------------------------------------------------------

CheckEveryFileIncluded(root, files) {
    referenced := Map()

    for path in files {
        for match in AllMatches(ReadText(path), "m)^[ \t]*#Include[ \t]+`"([^`"]+)`"[ \t]*$")
            referenced[StrLower(StrReplace(match.groups[1], "/", "\"))] := true
    }

    orphan := []

    for folder in gSourceFolders {
        loop files, root "\" folder "\*.ahk", "R" {
            relative := StrReplace(A_LoopFilePath, root "\", "")
            if !referenced.Has(StrLower(relative))
                orphan.Push(relative)
        }
    }

    Check(orphan.Length == 0,
        "every source file is #Included",
        orphan.Length ? "not included: " JoinList(orphan) : "")
}

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------

; The entry script plus every .ahk file under the project folders.
SourceFiles(root) {
    sources := [root "\CapsLock-.ahk"]
    for folder in gSourceFolders {
        loop files, root "\" folder "\*.ahk", "R"
            sources.Push(A_LoopFilePath)
    }
    return sources
}

Main() {
    root := RepoRoot()

    files := SourceFiles(root)

    Check(files.Length > 0, "source files were found", "root: " root)

    CheckIncludes(root, files)
    CheckFileInstalls(root, files)

    languageKeys := LoadLanguageKeys(root)
    CheckLanguageKeys(root, files, languageKeys)

    CheckShortcutBindings(root)
    CheckConfigRoundTrip(root)
    CheckPinIndicatorRegressions(root)
    CheckShiftLayerToastRegressions(root)
    CheckThemeTokenArchitecture(root)
    CheckEveryFileIncluded(root, files)

    Say("")
    Say("Hotkey regression checks: " gChecks " run, " gFailures.Length " failed.")

    if gFailures.Length {
        Say("")
        Say("Failures:")
        for failure in gFailures
            Say("  - " failure.name . (failure.detail != "" ? "  [" failure.detail "]" : ""))
        ExitApp(1)
    }

    Say("All checks passed.")
    ExitApp(0)
}

Main()
