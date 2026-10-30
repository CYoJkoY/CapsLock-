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
; the sources, apart from the quick phrase ranking probe, which calls the
; module's ordering helpers with fixed data.
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

; The ordering module is intentionally free of GUI and Store dependencies, so
; the ranking probe below can include it directly and execute the same helpers
; the application uses.
#Include "..\UI\QuickPhraseOrder.ahk"
#Include "..\Config\Globals.ahk"
#Include "..\Core\ImageTools.ahk"

; MouseControl.ahk is included stand-alone so its pure vector helper can be
; exercised. These minimal stubs stand in for the application modules it
; touches so the include stays loadable outside the full application.
class ApplicationProfiles {
    static IsHotkeysEnabledForActiveWindow() {
        return true
    }
}

class ShiftLayerToast {
    static ShowStatic(*) {
        return true
    }

    static Hide() {
    }
}

DeactivateShiftLayer(*) {
}

#Include "..\Core\MouseControl.ahk"

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

; Renders the ids of a quick phrase result list for a check diagnostic.
DescribeQuickPhraseIds(phrases) {
    ids := ""
    for phrase in phrases
        ids .= (ids == "" ? "" : ",") . phrase.id
    return "[" . ids . "]"
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

    ; Calls can span several lines, so trim and collapse the whitespace that
    ; sits around each argument before comparing the quoted literals.
    for match in AllMatches(text, "(Ini" kind "\s*\()") {
        start := match.pos + match.len
        closing := FindClosingParen(text, start)

        if !closing
            continue

        args := []
        for arg in SplitArguments(SubStr(text, start, closing - start))
            args.Push(RegExReplace(arg, "\s+", " "))

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

    ; The badge is shortcut feedback, not a mirror of WS_EX_TOPMOST. Only the
    ; CapsLock + T entry point may claim a window, and no discovery path may
    ; adopt a window that is topmost for some other reason.
    Check(
        InStr(pinText, "static OwnedWindows         := Map()") > 0
            && InStr(pinText, "if !this.OwnedWindows.Has(hwnd)") > 0
            && InStr(pinText, "&& this.OwnedWindows.Has(hwnd)") > 0
            && InStr(pinText, "ScanTopmostWindows") == 0,
        "pin badge is limited to windows pinned with CapsLock + T"
    )

    ; Disabling the indicator must keep the owned set so re-enabling it
    ; restores only shortcut-pinned windows, and theme rebuilds must do the same.
    Check(
        InStr(pinText, "static Clear(keepOwnership := false)") > 0
            && InStr(pinText, "this.Clear(true)") > 0
            && InStr(pinText, "this.ReconcileOwnedWindows()") > 0,
        "owned windows survive a disable or theme rebuild and are re-tracked from the owned set"
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
    Check(
        InStr(helperText, "static RefreshThemeResources()") > 0
            && InStr(helperText, "for hwnd, data in this._btnData.Clone()") > 0
            && InStr(helperText, "data.parentBgRef := this.RgbToColorRef(data.parentBg)") > 0,
        "theme refresh rebuilds live button draw metadata before redraws"
    )
    Check(
        InStr(helperText, "_InstallHeaderTextColor(ctrl, headerHwnd)") > 0
            && InStr(helperText, "_ThemeHelper_DrawListViewHeader") > 0
            && InStr(helperText, "ThemeHelper.RgbToColorRef(Theme.Text)") > 0,
        "dark ListView headers opt into custom draw with the palette text colour"
    )
    Check(
        InStr(helperText, "if headerHwnd && this.IsDark()") > 0
            && InStr(helperText, "this._InstallHeaderTextColor(ctrl, headerHwnd)") > 0
            && InStr(
                helperText,
                "CallbackCreate(_ThemeHelper_DrawListViewHeader, " . Chr(34) . "Fast" . Chr(34)
                    . ", 6)"
            ) > 0,
        "header colouring is installed only for dark lists with a header control"
    )
}

CheckCloudSyncRegressions(root) {
    guiText := ReadText(root "\UI\CloudSyncGui.ahk")
    Check(
        InStr(guiText, "enabled.Value := AppState.CloudSyncEnabled ? 1 : 0") > 0
            && InStr(guiText, "autoSync.Value := AppState.CloudSyncAutoEnabled ? 1 : 0") > 0,
        "cloud sync dialog restores saved checkbox states"
    )
    Check(
        InStr(guiText, "gistTokenValue := Trim(gistToken.Text)") > 0
            && InStr(guiText, "CloudSyncCredentials.Set(" . Chr(34) . "gist" . Chr(34)) > 0,
        "cloud sync dialog trims the gist token before saving"
    )
    Check(
        InStr(guiText, "gistTarget.Text := AppState.CloudSyncTarget") > 0
            && InStr(guiText, "if (provider.Text == " . Chr(34) . "GitHub Gist" . Chr(34) . ")") > 0,
        "cloud sync dialog refreshes the gist target after synchronization"
    )
    Check(
        InStr(guiText, "errorText .= " . Chr(34) . " " . Chr(34) . " AppState.CloudSyncLastError") > 0,
        "cloud sync connection failures include the provider error"
    )

    coordinatorText := ReadText(root "\Core\CloudSyncCoordinator.ahk")
    Check(
        RegExMatch(coordinatorText,
            "s)static Connect\(\*\).*?static ResetProvider",
            &connectMatch) > 0
            && InStr(connectMatch[0], "if !AppState.CloudSyncEnabled") == 0
            && InStr(
                connectMatch[0],
                "this._SetState(AppState.CloudSyncEnabled ? " . Chr(34) . "connected" . Chr(34)
                    . " : " . Chr(34) . "disabled" . Chr(34) . ")"
            ) > 0,
        "cloud sync connection validation does not require the enable switch"
    )

    providerText := ReadText(root "\Core\Providers\GitHubGistProvider.ahk")
    Check(
        InStr(providerText, "token := Trim(CloudSyncCredentials.Get(" . Chr(34) . "gist" . Chr(34)) > 0
            && InStr(providerText, "headers[" . Chr(34) . "Content-Type" . Chr(34) . "] := " . Chr(34) . "application/json" . Chr(34)) > 0
            && InStr(providerText, "this.ApiBase " . Chr(34) . "/gists?per_page=1" . Chr(34)) > 0,
        "gist provider trims tokens, sends JSON, and validates gist permissions"
    )
}

CheckQuickPhraseRegressions(root) {
    phraseText := ReadText(root "\UI\QuickPhraseGui.ahk")
    orderText := ReadText(root "\UI\QuickPhraseOrder.ahk")
    menuText := ReadText(root "\History\CustomMenu.ahk")
    rootText := ReadText(root "\CapsLock-.ahk")

    Check(
        InStr(phraseText, "groupFilter := myGui.Add(" . Chr(34) . "DropDownList" . Chr(34)) > 0
            && InStr(phraseText, "myGui.GroupFilter := groupFilter") > 0
            && InStr(phraseText, "QuickPhraseGroupFilterChanged(myGui)") > 0,
        "quick phrase selector and manager expose a shared group filter"
    )
    Check(
        InStr(phraseText, "phrasesForView := allPhrases") > 0
            && InStr(phraseText, "QuickPhraseFilterAndSort(phrasesForView") > 0
            && InStr(orderText, "return QuickPhraseSortByCategory(phrases)") > 0
            && InStr(orderText, "return QuickPhraseSortByCategory(allPhrases)") > 0
            && InStr(
                orderText,
                "&& QuickPhraseCompareDefault(entries[child], entries[child + 1]) < 0"
            ) > 0
            && InStr(
                orderText,
                "if QuickPhraseCompareDefault(entries[root], entries[child]) >= 0"
            ) > 0,
        "quick phrase views group empty queries by category and keep search tie-breaking"
    )
    Check(
        InStr(orderText, "QuickPhraseSortRankedPhrases(ranked)") > 0
            && InStr(
                orderText,
                "&& QuickPhraseCompareRanked(entries[child], entries[child + 1]) < 0"
            ) > 0
            && InStr(
                orderText,
                "if QuickPhraseCompareRanked(entries[root], entries[child]) >= 0"
            ) > 0
            && InStr(orderText, "return QuickPhraseComparePhrases(left.phrase, right.phrase)") > 0,
        "ranked search sorts through both comparator calls and ties by phrase order"
    )
    ; The ordering module is included at the top of this script, so these checks
    ; run the same code the application uses. The fixed phrases have unequal
    ; scores and the input lists the lower-scoring content match first, so a
    ; missing sort cannot pass.
    mixed := [
        { id: 11, name: "Send template", category: "", content: "alpha notes", order: 1 },
        { id: 12, name: "Alpha checklist", category: "", content: "steps", order: 2 },
        { id: 13, name: "Release note", category: "alpha", content: "misc", order: 3 }
    ]
    rankedResult := QuickPhraseFilterAndSort(mixed, "alpha", true)
    Check(
        rankedResult.Length == 3
            && rankedResult[1].id == 12
            && rankedResult[2].id == 13
            && rankedResult[3].id == 11,
        "ranked search puts the higher-scoring phrase first",
        DescribeQuickPhraseIds(rankedResult)
    )
    ties := [
        { id: 21, name: "Second entry", category: "", content: "beta", order: 2 },
        { id: 22, name: "First entry", category: "", content: "beta", order: 1 }
    ]
    tiedResult := QuickPhraseFilterAndSort(ties, "beta", true)
    Check(
        tiedResult.Length == 2 && tiedResult[1].id == 22 && tiedResult[2].id == 21,
        "equal ranked scores keep the stored phrase order",
        DescribeQuickPhraseIds(tiedResult)
    )
    unordered := [
        { id: 31, name: "Beta one", category: "beta", content: "", order: 2 },
        { id: 32, name: "Alpha two", category: "Alpha", content: "", order: 1 },
        { id: 33, name: "Raw note", category: "", content: "", order: 3 },
        { id: 34, name: "Alpha one", category: "alpha", content: "", order: 2 }
    ]
    categoryResult := QuickPhraseFilterAndSort(unordered, "")
    Check(
        categoryResult.Length == 4
            && categoryResult[1].id == 32
            && categoryResult[2].id == 34
            && categoryResult[3].id == 31
            && categoryResult[4].id == 33,
        "empty query groups categories in order and keeps stored order within a group",
        DescribeQuickPhraseIds(categoryResult)
    )
    Check(
        unordered[1].id == 31 && unordered[2].id == 32 && unordered[4].id == 34,
        "sorting does not reorder the caller's phrase array"
    )
    Check(
        QuickPhraseGroupMatches({ category: "Work" }, " work ") == true
            && QuickPhraseGroupMatches({ category: "Work" }, "personal") == false
            && QuickPhraseGroupMatches({ category: "" }, "") == true,
        "group filter matches categories case-insensitively and empty selects all"
    )
    Check(
        InStr(rootText, "QuickPhraseStore.SetOnChange(QuickPhraseRefreshOpenViews)") > 0
            && InStr(phraseText, "QuickPhraseRefreshGroupFilter(manager)") > 0
            && InStr(phraseText, "QuickPhraseRefreshGroupFilter(selector)") > 0
            && InStr(phraseText, "selectedIndexBeforeRefresh := groupFilter.Value") > 0
            && InStr(phraseText, "if selectedIndexBeforeRefresh > 1") > 0,
        "quick phrase Store changes refresh open lists and group options"
    )
    Check(
        InStr(menuText, Chr(34) . "x0 y" . Chr(34) . " curY " . Chr(34) . " w" . Chr(34) . " menuW") > 0
            && InStr(menuText, Chr(34) . "x0 y" . Chr(34) . " subCurY " . Chr(34) . " w" . Chr(34) . " subMenuW") > 0
            && InStr(menuText, Chr(34) . "x0 y" . Chr(34) . " curY " . Chr(34) . " w" . Chr(34) . " nestedMenuW") > 0,
        "custom menu hover surfaces cover all three menu row widths"
    )
}

CheckImageToolsHotkeys(root) {
    bindings := ReadText(root "\Hotkeys\HotkeyBindings.ahk")
    reference := ReadText(root "\Hotkeys\HotkeyReference.ahk")
    Check(
        InStr(bindings, "i:: ImageToolsGui.Toggle()") > 0
            && InStr(bindings, "i:: SettingsGui.Toggle()") == 0
            && InStr(bindings, ",:: SettingsGui.Toggle()") > 0
            && InStr(reference, "keys: " . Chr(34) . "CapsLock + I" . Chr(34)) > 0
            && InStr(reference, "keys: " . Chr(34) . "CapsLock + ," . Chr(34)) > 0,
        "CapsLock+I opens image tools and CapsLock+Comma opens settings"
    )
}

CheckImageToolsDefaultOutput(root) {
    Check(
        ImageTools.DefaultOutputDirectory([]) == "",
        "image tools default output is empty for an empty path list"
    )
    Check(
        ImageTools.DefaultOutputDirectory(["C:\Images\a.png"]) == "C:\Images",
        "image tools default output uses the first image directory"
    )
    Check(
        ImageTools.DefaultOutputDirectory(["", 42, "D:\Sets\b.png", "E:\Other\c.png"]) == "D:\Sets",
        "image tools default output skips unusable entries and keeps the first image directory"
    )
    Check(
        ImageTools.DefaultOutputDirectory("C:\Images\a.png") == "",
        "image tools default output rejects a non-array path list"
    )

    guiText := ReadText(root "\UI\ImageToolsGui.ahk")
    Check(
        InStr(guiText, "outputDirectory.OnEvent(" . Chr(34) . "Change" . Chr(34)) > 0
            && InStr(guiText, "this.AutoOutputDirectory := false") > 0
            && InStr(guiText, "this._RefreshAutoOutputDirectory()") > 0,
        "image tools wire automatic output directory selection to manual overrides"
    )
}

CheckMouseControlRegressions(root) {
    moduleText := ReadText(root "\Core\MouseControl.ahk")
    bindings := ReadText(root "\Hotkeys\HotkeyBindings.ahk")
    rootText := ReadText(root "\CapsLock-.ahk")
    osdText := ReadText(root "\UI\OSD.ahk")

    ; The vector helper is pure and can be exercised directly. Cardinal input
    ; must have unit length and every diagonal must be normalized to the same
    ; length, otherwise diagonal movement would outrun a single direction.
    up := MouseControl.MovementVector(true, false, false, false)
    left := MouseControl.MovementVector(false, true, false, false)
    down := MouseControl.MovementVector(false, false, true, false)
    right := MouseControl.MovementVector(false, false, false, true)
    Check(
        up.x == 0 && up.y == -1
            && left.x == -1 && left.y == 0
            && down.x == 0 && down.y == 1
            && right.x == 1 && right.y == 0,
        "mouse movement vectors map W / A / S / D to up / left / down / right"
    )

    diagonals := [
        MouseControl.MovementVector(true, true, false, false),
        MouseControl.MovementVector(true, false, false, true),
        MouseControl.MovementVector(false, true, true, false),
        MouseControl.MovementVector(false, false, true, true)
    ]
    diagonalOk := true
    for vector in diagonals {
        length := Sqrt(vector.x * vector.x + vector.y * vector.y)
        if Abs(length - 1) > 0.0001
            diagonalOk := false
    }
    Check(
        diagonalOk
            && diagonals[1].x < 0 && diagonals[1].y < 0
            && diagonals[2].x > 0 && diagonals[2].y < 0
            && diagonals[3].x < 0 && diagonals[3].y > 0
            && diagonals[4].x > 0 && diagonals[4].y > 0,
        "diagonal mouse movement is normalized in all four directions"
    )

    zero := MouseControl.MovementVector(false, false, false, false)
    canceledX := MouseControl.MovementVector(false, true, false, true)
    canceledY := MouseControl.MovementVector(true, false, true, false)
    Check(
        zero.x == 0 && zero.y == 0
            && canceledX.x == 0 && canceledX.y == 0
            && canceledY.x == 0 && canceledY.y == 0,
        "opposing or empty mouse directions produce no movement"
    )

    Check(
        InStr(moduleText, "static NativeCapsLockOn()") > 0
            && InStr(moduleText, "GetKeyState(" . Chr(34) . "CapsLock" . Chr(34) . ", " . Chr(34) . "T" . Chr(34) . ")") > 0
            && InStr(moduleText, "!AppState.QuickPhraseTransactionActive") > 0
            && InStr(moduleText, "ApplicationProfiles.IsHotkeysEnabledForActiveWindow()") > 0,
        "mouse control entry requires an enabled CapsLock layer and the native light"
    )

    Check(
        InStr(rootText, "#Include " . Chr(34) . "Core\MouseControl.ahk" . Chr(34)) > 0
            && InStr(rootText, "MouseControl.Stop()") > 0,
        "mouse control is included and stopped during application shutdown"
    )

    Check(
        InStr(bindings, "#HotIf MouseControl.EntryAvailable() || MouseControl.Active") > 0
            && InStr(bindings, "*Shift:: MouseControl.ToggleFromShift()") > 0
            && InStr(bindings, "~*Shift up:: MouseControl.ShiftReleased()") > 0
            && InStr(bindings, "*Esc:: MouseControl.Stop()") > 0,
        "Shift toggles mouse control and Esc exits it"
    )

    movementWired := true
    for key in ["w", "a", "s", "d"] {
        downPattern := "*" key ":: MouseControl.UpdateMovementTimer()"
        upPattern := "*" key " up:: MouseControl.UpdateMovementTimer()"
        if InStr(bindings, downPattern) == 0 || InStr(bindings, upPattern) == 0
            movementWired := false
    }
    Check(movementWired, "W / A / S / D drive the movement timer on press and release")

    buttonsWired := true
    for pair in [["j", "left"], ["k", "middle"], ["l", "right"]] {
        downPattern := "*" pair[1] ":: MouseControl.PressButton(" . Chr(34) . pair[2] . Chr(34) . ")"
        upPattern := "*" pair[1] " up:: MouseControl.ReleaseButton(" . Chr(34) . pair[2] . Chr(34) . ")"
        if InStr(bindings, downPattern) == 0 || InStr(bindings, upPattern) == 0
            buttonsWired := false
    }
    Check(buttonsWired, "J / K / L hold and release the left / middle / right mouse buttons")

    Check(
        InStr(bindings, "*i:: MouseControl.StartScroll(" . Chr(34) . "up" . Chr(34) . ")") > 0
            && InStr(bindings, "*i up:: MouseControl.StopScroll(" . Chr(34) . "up" . Chr(34) . ")") > 0
            && InStr(bindings, "*m:: MouseControl.StartScroll(" . Chr(34) . "down" . Chr(34) . ")") > 0
            && InStr(bindings, "*m up:: MouseControl.StopScroll(" . Chr(34) . "down" . Chr(34) . ")") > 0
            && InStr(moduleText, "GetKeyState(" . Chr(34) . "Alt" . Chr(34) . ", " . Chr(34) . "P" . Chr(34) . ")") > 0,
        "I / M repeat wheel scrolling and Alt selects the larger step"
    )

    ; Double Shift is a timing gesture, so the boundary is exercised through
    ; the pure helper instead of a synthetic keyboard. Zero, reversed, and
    ; late input must all be rejected; exactly the window is still a pair.
    Check(
        MouseControl.ShiftEntryWindow == 450
            && MouseControl.IsDoubleShiftWithinWindow(0, 100) == false
            && MouseControl.IsDoubleShiftWithinWindow(100, 0) == false
            && MouseControl.IsDoubleShiftWithinWindow(5000, 4000) == false
            && MouseControl.IsDoubleShiftWithinWindow(1000, 1450) == true
            && MouseControl.IsDoubleShiftWithinWindow(1000, 1451) == false,
        "double Shift accepts exactly the entry window and rejects zero or reversed ticks"
    )
    Check(
        InStr(bindings, "*Shift:: MouseControl.ToggleFromShift()") > 0
            && InStr(moduleText, "static ToggleFromShift(*)") > 0
            && InStr(moduleText, "if this.Active {") > 0
            && InStr(moduleText, "this.LastShiftTick := now") > 0,
        "a single Shift exits while two taps within the window enter mouse control"
    )

    ; Speed normalization is pure and runs on load, save, and every movement
    ; tick, so the range guard is checked directly.
    Check(
        MouseControl.NormalizeSpeedPercent(100) == 100
            && MouseControl.NormalizeSpeedPercent(20) == 20
            && MouseControl.NormalizeSpeedPercent(300) == 300,
        "cursor speed accepts values inside the 20 to 300 range"
    )
    Check(
        MouseControl.NormalizeSpeedPercent("not a number") == 100
            && MouseControl.NormalizeSpeedPercent("") == 100,
        "invalid cursor speed falls back to 100 percent"
    )
    Check(
        MouseControl.NormalizeSpeedPercent(1) == 20
            && MouseControl.NormalizeSpeedPercent(19) == 20
            && MouseControl.NormalizeSpeedPercent(301) == 300
            && MouseControl.NormalizeSpeedPercent(9999) == 300,
        "cursor speed clamps to the configured minimum and maximum"
    )
    Check(
        MouseControl.NormalizeSpeedPercent("150") == 150,
        "numeric cursor speed text is accepted"
    )

    ; Horizontal wheel input needs its own bindings, flag, repeat timer, and
    ; Alt fast step, and Stop() must tear the timer down like the vertical one.
    Check(
        InStr(bindings, "*q:: MouseControl.StartHorizontalScroll(" . Chr(34) . "left" . Chr(34) . ")") > 0
            && InStr(bindings, "*q up:: MouseControl.StopHorizontalScroll(" . Chr(34) . "left" . Chr(34) . ")") > 0
            && InStr(bindings, "*e:: MouseControl.StartHorizontalScroll(" . Chr(34) . "right" . Chr(34) . ")") > 0
            && InStr(bindings, "*e up:: MouseControl.StopHorizontalScroll(" . Chr(34) . "right" . Chr(34) . ")") > 0,
        "Q / E start and stop horizontal scrolling in both directions"
    )
    Check(
        InStr(moduleText, "this._MouseEvent(0x1000, 0, 0, right ? step : -step)") > 0
            && InStr(moduleText, "static HorizontalScrollTick(*)") > 0
            && InStr(moduleText, "step := GetKeyState(" . Chr(34) . "Alt" . Chr(34) . ", " . Chr(34) . "P" . Chr(34) . ") ? this.ScrollFastStep : this.ScrollStep") > 0,
        "horizontal scrolling uses MOUSEEVENTF_HWHEEL and the Alt fast step"
    )
    Check(
        InStr(moduleText, "this._StopHorizontalScrollTimer()") > 0
            && InStr(moduleText, "static _StopHorizontalScrollTimer()") > 0,
        "stopping mouse control stops the horizontal scroll timer"
    )

    Check(
        InStr(moduleText, "this._ReleaseAllButtons()") > 0
            && InStr(moduleText, "ShiftLayerToast.Hide()") > 0
            && InStr(moduleText, "this._StopMovementTimer()") > 0
            && InStr(moduleText, "this._StopScrollTimer()") > 0,
        "stopping mouse control releases buttons and stops every timer"
    )

    Check(
        InStr(bindings, "&& !MouseControl.Active") > 0
            && InStr(bindings, "#HotIf CapsLockHotkeysAvailable() && !MouseControl.EntryAvailable()") > 0,
        "the normal CapsLock and sequential Shift layers are disabled in mouse mode"
    )

    staticStart := InStr(osdText, "static ShowStatic(")
    staticEnd := staticStart ? InStr(osdText, "static Hide()", false, staticStart) : 0
    staticSection := (staticStart && staticEnd) ? SubStr(osdText, staticStart, staticEnd - staticStart) : ""
    Check(
        staticStart && staticEnd
            && InStr(osdText, "static StaticMode := false") > 0
            && InStr(osdText, "if this.StaticMode") > 0
            && InStr(staticSection, "this.UpdateInterval") == 0
            && InStr(staticSection, "this._Tick()") == 0,
        "the mouse mode indicator is a static bar without a countdown timer"
    )
}

; ---------------------------------------------------------------------------
; 7: every source file is reachable
; ---------------------------------------------------------------------------

CheckEveryFileIncluded(root, files) {
    referenced := Map()

    for path in files {
        SplitPath(path, , &directory)
        for match in AllMatches(ReadText(path), "m)^[ \t]*#Include[ \t]+`"([^`"]+)`"[ \t]*$") {
            ; Resolve against the including file, then normalise to a path
            ; relative to the repository root so nested folders compare evenly.
            absolute := directory . "\" . StrReplace(match.groups[1], "/", "\")
            referenced[StrLower(StrReplace(absolute, root . "\", ""))] := true
        }
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
    CheckCloudSyncRegressions(root)
    CheckQuickPhraseRegressions(root)
    CheckImageToolsHotkeys(root)
    CheckImageToolsDefaultOutput(root)
    CheckMouseControlRegressions(root)
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
