#Requires AutoHotkey v2.0

SetPasteMode(mode) {
    AppState.PasteMode := mode
    ConfigManager.Save()
    ToolTip(mode == 1 ? Lang("MSG_PASTE_MODE_FILE") : Lang("MSG_PASTE_MODE_TEXT"))
    SetTimer(() => ToolTip(), -2000)
}

SetDeleteMode(mode) {
    AppState.DeleteMode := mode
    ConfigManager.Save()
    msgs := [Lang("MSG_DELETE_MODE_DELAY"), Lang("MSG_DELETE_MODE_BATCH"), Lang("MSG_DELETE_MODE_NEVER")]
    ToolTip(msgs[mode])
    SetTimer(() => ToolTip(), -2000)
}

SetTheme(mode, *) {
    Theme.Set(mode)
}

SetMaxHistory(*) {
    input := DarkInputDialog.Show(
        Lang("INPUT_MAX_HISTORY_PROMPT"),
        Lang("INPUT_MAX_HISTORY_TITLE"),
        AppState.MaxHistory
    )
    if input.Result != "OK" || !IsNumber(input.Value)
        return
    newMax := Integer(input.Value)
    if newMax < 0
        newMax := 0

    if newMax == 0 {
        if AppState.History.Length > 0 {
            confirm := MsgBox(Lang("CONFIRM_DISABLE_HISTORY", , AppState.History.Length), Lang("MSG_CONFIRM"), "YesNo Icon?")
            if confirm != "Yes"
                return
        }
        AppState.MaxHistory := 0
        ConfigManager.Save()
        HistoryManager.Trim(0)
        HistoryManager.ForceSave()
        ToolTip(Lang("MSG_HISTORY_DISABLED"))
        SetTimer(() => ToolTip(), -3000)
        return
    }

    pendingRemoval := AppState.History.Length - newMax
    if pendingRemoval > 0 {
        confirm := MsgBox(Lang("CONFIRM_TRIM_HISTORY", , AppState.History.Length, newMax, pendingRemoval), Lang("MSG_CONFIRM"), "YesNo Icon?")
        if confirm != "Yes"
            return
    }

    AppState.MaxHistory := newMax
    ConfigManager.Save()
    HistoryManager.Trim(AppState.MaxHistory)
    HistoryManager.ForceSave()
    ToolTip(Lang("MSG_HISTORY_LIMIT_SET", , newMax))
    SetTimer(() => ToolTip(), -3000)
}

SetDeleteDelay(*) {
    input := DarkInputDialog.Show(
        Lang("INPUT_DELAY_PROMPT"),
        Lang("INPUT_DELAY_TITLE"),
        AppState.DeleteDelay
    )
    if input.Result == "OK" && IsNumber(input.Value) && input.Value > 0 {
        AppState.DeleteDelay := Integer(input.Value)
        ConfigManager.Save()
        ToolTip(Lang("MSG_DELAY_SET", , AppState.DeleteDelay))
        SetTimer(() => ToolTip(), -2000)
    }
}

SetCleanupInterval(*) {
    input := DarkInputDialog.Show(
        Lang("INPUT_INTERVAL_PROMPT"),
        Lang("INPUT_INTERVAL_TITLE"),
        AppState.CleanupInterval
    )
    if input.Result == "OK" && IsNumber(input.Value) && input.Value > 0 {
        AppState.CleanupInterval := Integer(input.Value)
        ConfigManager.Save()
        ToolTip(Lang("MSG_INTERVAL_SET", , AppState.CleanupInterval))
        SetTimer(() => ToolTip(), -2000)
    }
}

SetImPath(*) {
    SelectedFile := Trim(FileSelect(1, A_ProgramFiles, Lang("GUI_IM_SELECT_TITLE"), Lang("GUI_IM_SELECT_FILTER")))
    if SelectedFile == ""
        return
    if !InStr(StrLower(SelectedFile), "magick.exe") {
        MsgBox(Lang("MSG_IM_SELECT_ERROR"), Lang("MSG_ERROR"), "Iconx")
        return
    }
    if !FileExist(SelectedFile) {
        MsgBox(Lang("MSG_IM_FILE_NOT_EXIST"), Lang("MSG_ERROR"), "Iconx")
        return
    }
    AppState.ImageMagickExe := SelectedFile
    try {
        ConfigManager.Save()
    } catch {
        MsgBox(Lang("MSG_IM_SAVE_FAIL"), Lang("MSG_ERROR"), "Iconx")
        return
    }
    MsgBox(Lang("MSG_IM_SET_SUCCESS", , SelectedFile), Lang("MSG_SUCCESS"), "Iconi T2")
}

SetIgnorePatterns(*) {
    myGui := Gui("+AlwaysOnTop +MinSize540x380", Lang("GUI_IGNORE_TITLE"))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, "— " Lang("GUI_IGNORE_TITLE"), 500)
    ThemeHelper.AddSubtitle(myGui,
        Lang("GUI_IGNORE_PROMPT", , "One pattern per line. Supports gitignore syntax."), 500)
    ThemeHelper.AddSeparator(myGui, 500)

    myGui.SetFont("s10 c" Theme.Text, Theme.FontMono)
    myEdit := myGui.Add(
        "Edit",
        "Multi VScroll w500 h200 y+12 " ThemeHelper.GetEditOptions(),
        ""
    )
    ThemeHelper.StyleEdit(myEdit)
    myGui.SetFont("s10 c" Theme.Text, Theme.Font)

    current := ""
    for pattern in AppState.IgnorePatterns
        current .= pattern "`n"
    myEdit.Value := RTrim(current, "`n")

    btnOK := ThemeHelper.AddButton(myGui, "Default w90 y+12", "✓ " Lang("GUI_OK"), "primary")
    btnCancel := ThemeHelper.AddButton(myGui, "x+8 w90", "✕ " Lang("GUI_CANCEL"))
    btnOK.OnEvent("Click", (*) => SaveIgnoreRules(myEdit.Text, myGui))
    btnCancel.OnEvent("Click", (*) => myGui.Destroy())

    myGui.OnEvent("Escape", (*) => myGui.Destroy())
    ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
    myGui.Show()
}

SaveIgnoreRules(text, myGui) {
    newPatterns := []
    lines := StrSplit(text, "`n", "`r")
    for line in lines {
        line := Trim(line)
        if line != ""
            newPatterns.Push(line)
    }
    AppState.IgnorePatterns := newPatterns
    ConfigManager.Save()
    myGui.Destroy()
    FileHelper.BuildIgnoreRegexes()
    ToolTip(Lang("MSG_IGNORE_UPDATED"))
    SetTimer(() => ToolTip(), -2000)
}

SetPandocPath(*) {
    SelectedFile := Trim(FileSelect(1, A_ProgramFiles, Lang("INPUT_PANDOC_PATH_TITLE", "Select Pandoc executable"), Lang("INPUT_PANDOC_PATH_FILTER", "Pandoc.exe")))
    if (SelectedFile == "")
        return

    if !InStr(StrLower(SelectedFile), "pandoc.exe") {
        MsgBox(Lang("MSG_PANDOC_SELECT_ERROR", "Please select pandoc.exe"), Lang("MSG_ERROR"), "Iconx")
        return
    }

    if !FileExist(SelectedFile) {
        MsgBox(Lang("MSG_PANDOC_FILE_NOT_EXIST", "File does not exist"), Lang("MSG_ERROR"), "Iconx")
        return
    }

    AppState.PandocExe := SelectedFile
    ConfigManager.Save()
    MsgBox(Lang("MSG_PANDOC_PATH_SET", , SelectedFile), Lang("MSG_SUCCESS"), "Iconi T2")
}

_SortStrings(arr) {
    n := arr.Length
    if n <= 1
        return arr
    Loop n - 1 {
        swapped := false
        Loop n - A_Index {
            if (StrCompare(arr[A_Index], arr[A_Index + 1]) > 0) {
                tmp := arr[A_Index]
                arr[A_Index] := arr[A_Index + 1]
                arr[A_Index + 1] := tmp
                swapped := true
            }
        }
        if !swapped
            break
    }
    return arr
}

SetPandocOutput(*) {
    myGui := Gui("+AlwaysOnTop", Lang("INPUT_PANDOC_OUTPUT_TITLE", "Select Pandoc Output Format"))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, "↑ " Lang("INPUT_PANDOC_OUTPUT_TITLE"), 420)
    ThemeHelper.AddSubtitle(myGui, Lang("INPUT_PANDOC_OUTPUT_PROMPT", "Choose output format:"), 420)
    ThemeHelper.AddSeparator(myGui, 420)

    myGui.SetFont("s10 c" Theme.Text, Theme.Font)
    formats := AppState.PandocOutputFormats.Clone()
    _SortStrings(formats)

    cbo := myGui.Add(
        "ComboBox",
        "w320 vOutputFormat Choose1 c" Theme.Text " Background" Theme.Control,
        formats
    )
    ThemeHelper.StyleComboBox(cbo)

    current := AppState.PandocOutputFormat
    Loop formats.Length {
        if (formats[A_Index] == current) {
            cbo.Choose(A_Index)
            break
        }
    }

    btnOK := ThemeHelper.AddButton(myGui, "Default w90 y+16", "✓ " Lang("GUI_OK"), "primary")
    btnCancel := ThemeHelper.AddButton(myGui, "x+8 w90", "✕ " Lang("GUI_CANCEL"))

    btnOK.OnEvent("Click", (*) => SavePandocOutput(cbo.Text, myGui))
    btnCancel.OnEvent("Click", (*) => myGui.Destroy())
    myGui.OnEvent("Escape", (*) => myGui.Destroy())
    ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
    myGui.Show("AutoSize Center")
}

SavePandocOutput(newFormat, myGui) {
    if (newFormat == "") {
        myGui.Destroy()
        return
    }

    if (!_IsOutputFormatSupported(newFormat)) {
        hwnd := myGui.Hwnd
        WinSetAlwaysOnTop(0, "ahk_id " hwnd)
        MsgBox(
            Lang("MSG_PANDOC_INVALID_OUTPUT", "Invalid output format: {1}", newFormat),
            Lang("MSG_ERROR"),
            "Iconx T"
        )
        WinSetAlwaysOnTop(1, "ahk_id " hwnd)
        myGui.Destroy()
        return
    }

    AppState.PandocOutputFormat := newFormat
    ConfigManager.Save()
    hwnd := myGui.Hwnd
    WinSetAlwaysOnTop(0, "ahk_id " hwnd)
    MsgBox(
        Lang("MSG_PANDOC_OUTPUT_SET", , newFormat),
        Lang("MSG_SUCCESS"),
        "Iconi T2"
    )
    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
    myGui.Destroy()
}


SetWindowHoleDiameter(*) {
    input := DarkInputDialog.Show(
        Lang("INPUT_WINDOW_HOLE_SIZE_PROMPT", "Enter hole diameter (80-1200 px)."),
        Lang("INPUT_WINDOW_HOLE_SIZE_TITLE", "Window Hole Size"),
        AppState.WindowHoleDiameter
    )

    if input.Result != "OK" || !IsNumber(input.Value)
        return

    diameter := Integer(input.Value)
    if diameter < 80
        diameter := 80
    else if diameter > 1200
        diameter := 1200

    AppState.WindowHoleDiameter := diameter
    ConfigManager.Save()
    ShowToolTip(Lang("MSG_WINDOW_HOLE_SIZE_SET", "Window hole size set to {1}px.", diameter), 1800)
}

SetWindowHoleShape(shape, *) {
    shape := StrLower(shape)
    if shape != "circle" && shape != "rounded" && shape != "square"
        return

    AppState.WindowHoleShape := shape
    ConfigManager.Save()

    labels := Map(
        "circle", Lang("MENU_WINDOW_HOLE_SHAPE_CIRCLE", "Circle"),
        "rounded", Lang("MENU_WINDOW_HOLE_SHAPE_ROUNDED", "Rounded rectangle"),
        "square", Lang("MENU_WINDOW_HOLE_SHAPE_SQUARE", "Square")
    )
    ShowToolTip(
        Lang("MSG_WINDOW_HOLE_SHAPE_SET", "Window hole shape: {1}.", labels[shape]),
        1800
    )
}


SetWindowHoleActivation(mode, *) {
    mode := StrLower(mode)
    if mode != "hold" && mode != "toggle"
        return

    AppState.WindowHoleActivation := mode
    ConfigManager.Save()

    key := mode == "hold"
        ? "MSG_WINDOW_HOLE_ACTIVATION_HOLD"
        : "MSG_WINDOW_HOLE_ACTIVATION_TOGGLE"
    fallback := mode == "hold"
        ? "Window Hole uses hold mode."
        : "Window Hole uses toggle mode."
    ShowToolTip(Lang(key, fallback), 1800)
}

ToggleWindowHoleFallback(*) {
    AppState.WindowHoleFallbackToMinimize := !AppState.WindowHoleFallbackToMinimize
    ConfigManager.Save()

    key := AppState.WindowHoleFallbackToMinimize
        ? "MSG_WINDOW_HOLE_FALLBACK_ENABLED"
        : "MSG_WINDOW_HOLE_FALLBACK_DISABLED"
    fallback := AppState.WindowHoleFallbackToMinimize
        ? "Incompatible windows will be temporarily minimized."
        : "Incompatible windows will be left unchanged."
    ShowToolTip(Lang(key, fallback), 2200)
}

SetWindowHoleRules(*) {
    myGui := Gui("+AlwaysOnTop +MinSize620x700", Lang("GUI_WINDOW_HOLE_RULES", "Window Hole Rules"))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, Lang("GUI_WINDOW_HOLE_RULES", "Window Hole Rules"), 560)
    ThemeHelper.AddSubtitle(
        myGui,
        Lang(
            "GUI_WINDOW_HOLE_RULES_PROMPT",
            "One executable name or window class per line. Empty allow-lists mean all windows are eligible. Excluded entries always win."
        ),
        560
    )
    ThemeHelper.AddSeparator(myGui, 560)

    myGui.SetFont("s9 c" Theme.Text, Theme.Font)

    myGui.AddText(
        "x30 y+10 w560",
        Lang("GUI_WINDOW_HOLE_ALLOW_EXE", "Allowed executables (optional)")
    )
    allowExe := myGui.Add(
        "Edit",
        "Multi VScroll x30 y+6 w560 h70 " ThemeHelper.GetEditOptions(),
        Join(AppState.WindowHoleAllowedExecutables, Chr(10))
    )
    ThemeHelper.StyleEdit(allowExe)

    myGui.AddText(
        "x30 y+10 w560",
        Lang("GUI_WINDOW_HOLE_EXCLUDE_EXE", "Excluded executables")
    )
    excludeExe := myGui.Add(
        "Edit",
        "Multi VScroll x30 y+6 w560 h70 " ThemeHelper.GetEditOptions(),
        Join(AppState.WindowHoleExcludedExecutables, Chr(10))
    )
    ThemeHelper.StyleEdit(excludeExe)

    myGui.AddText(
        "x30 y+10 w560",
        Lang("GUI_WINDOW_HOLE_ALLOW_CLASS", "Allowed window classes (optional)")
    )
    allowClass := myGui.Add(
        "Edit",
        "Multi VScroll x30 y+6 w560 h70 " ThemeHelper.GetEditOptions(),
        Join(AppState.WindowHoleAllowedClasses, Chr(10))
    )
    ThemeHelper.StyleEdit(allowClass)

    myGui.AddText(
        "x30 y+10 w560",
        Lang("GUI_WINDOW_HOLE_EXCLUDE_CLASS", "Excluded window classes")
    )
    excludeClass := myGui.Add(
        "Edit",
        "Multi VScroll x30 y+6 w560 h70 " ThemeHelper.GetEditOptions(),
        Join(AppState.WindowHoleExcludedClasses, Chr(10))
    )
    ThemeHelper.StyleEdit(excludeClass)

    myGui.SetFont("s10 c" Theme.Text, Theme.Font)

    btnOK := ThemeHelper.AddButton(
        myGui,
        "Default w100 x30 y+18",
        "✓ " Lang("GUI_OK"),
        "primary"
    )
    btnCancel := ThemeHelper.AddButton(
        myGui,
        "x+8 w100",
        "✕ " Lang("GUI_CANCEL")
    )

    btnOK.OnEvent(
        "Click",
        (*) => SaveWindowHoleRules(
            allowExe.Text,
            excludeExe.Text,
            allowClass.Text,
            excludeClass.Text,
            myGui
        )
    )
    btnCancel.OnEvent("Click", (*) => myGui.Destroy())
    myGui.OnEvent("Escape", (*) => myGui.Destroy())

    ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
    myGui.Show("AutoSize Center")
}

SaveWindowHoleRules(allowExeText, excludeExeText, allowClassText, excludeClassText, myGui) {
    AppState.WindowHoleAllowedExecutables := _ParseWindowHoleRuleList(allowExeText)
    AppState.WindowHoleExcludedExecutables := _ParseWindowHoleRuleList(excludeExeText)
    AppState.WindowHoleAllowedClasses := _ParseWindowHoleRuleList(allowClassText)
    AppState.WindowHoleExcludedClasses := _ParseWindowHoleRuleList(excludeClassText)

    ConfigManager.Save()
    myGui.Destroy()

    ShowToolTip(
        Lang("MSG_WINDOW_HOLE_RULES_SAVED", "Window Hole rules saved."),
        1800
    )
}

; --- Dynamic Zoom (CapsLock + Z) ---

SetZoomFactor(*) {
    input := DarkInputDialog.Show(
        Lang("INPUT_ZOOM_FACTOR_PROMPT", "Magnification factor (2-16)."),
        Lang("INPUT_ZOOM_FACTOR_TITLE", "Zoom factor"),
        AppState.ZoomFactor
    )

    if input.Result != "OK" || !IsNumber(input.Value)
        return

    value := Clamp(Integer(input.Value), 2, 16)
    AppState.ZoomFactor := value
    ConfigManager.Save()
    Zoom.Refresh()
    ShowToolTip(Lang("MSG_ZOOM_FACTOR_SET", "Zoom factor: {1}x.", value), 1800)
}

SetZoomActivation(mode, *) {
    mode := StrLower(mode)
    if !_IsAllowedValue(mode, AppState.ZoomActivations)
        return

    AppState.ZoomActivation := mode
    ConfigManager.Save()

    key := mode == "hold"
        ? "MSG_ZOOM_ACTIVATION_HOLD"
        : "MSG_ZOOM_ACTIVATION_TOGGLE"
    fallback := mode == "hold"
        ? "Zoom stays on while Z is held."
        : "Zoom toggles on and off with Z."

    ShowToolTip(Lang(key, fallback), 2000)
}

; --- Spotlight (CapsLock + O) ---
;
; Every setter writes the value, persists it, and then asks the running
; effect to re-apply itself so a change is visible immediately without having
; to restart the spotlight.

SetSpotlightRadius(*) {
    input := DarkInputDialog.Show(
        Lang("INPUT_SPOTLIGHT_RADIUS_PROMPT", "Clear radius in pixels (40-900)."),
        Lang("INPUT_SPOTLIGHT_RADIUS_TITLE", "Spotlight radius"),
        AppState.SpotlightRadius
    )

    if input.Result != "OK" || !IsNumber(input.Value)
        return

    value := Clamp(Integer(input.Value), 40, 900)
    AppState.SpotlightRadius := value
    ConfigManager.Save()
    Spotlight.Refresh()
    ShowToolTip(Lang("MSG_SPOTLIGHT_RADIUS_SET", "Spotlight radius: {1} px.", value), 1800)
}

SetSpotlightSoftness(*) {
    input := DarkInputDialog.Show(
        Lang("INPUT_SPOTLIGHT_SOFTNESS_PROMPT", "Edge softness in pixels (0-250, 0 = hard edge)."),
        Lang("INPUT_SPOTLIGHT_SOFTNESS_TITLE", "Spotlight edge softness"),
        AppState.SpotlightSoftness
    )

    if input.Result != "OK" || !IsNumber(input.Value)
        return

    value := Clamp(Integer(input.Value), 0, 250)
    AppState.SpotlightSoftness := value
    ConfigManager.Save()
    Spotlight.Refresh()
    ShowToolTip(Lang("MSG_SPOTLIGHT_SOFTNESS_SET", "Spotlight edge softness: {1} px.", value), 1800)
}

SetSpotlightDarkness(*) {
    input := DarkInputDialog.Show(
        Lang("INPUT_SPOTLIGHT_DARKNESS_PROMPT", "Dim opacity in percent (5-95)."),
        Lang("INPUT_SPOTLIGHT_DARKNESS_TITLE", "Spotlight dim opacity"),
        AppState.SpotlightDarkness
    )

    if input.Result != "OK" || !IsNumber(input.Value)
        return

    value := Clamp(Integer(input.Value), 5, 95)
    AppState.SpotlightDarkness := value
    ConfigManager.Save()
    Spotlight.Refresh()
    ShowToolTip(Lang("MSG_SPOTLIGHT_DARKNESS_SET", "Spotlight dim opacity: {1}%.", value), 1800)
}

SetSpotlightShape(shape, *) {
    shape := StrLower(shape)
    if !_IsAllowedValue(shape, AppState.SpotlightShapes)
        return

    AppState.SpotlightShape := shape
    ConfigManager.Save()
    Spotlight.Refresh()

    labels := Map(
        "circle",  Lang("MENU_SPOTLIGHT_SHAPE_CIRCLE", "Circle"),
        "rounded", Lang("MENU_SPOTLIGHT_SHAPE_ROUNDED", "Rounded rectangle"),
        "square",  Lang("MENU_SPOTLIGHT_SHAPE_SQUARE", "Square")
    )

    ShowToolTip(
        Lang("MSG_SPOTLIGHT_SHAPE_SET", "Spotlight shape: {1}.", labels[shape]),
        1800
    )
}

SetSpotlightActivation(mode, *) {
    mode := StrLower(mode)
    if !_IsAllowedValue(mode, AppState.SpotlightActivations)
        return

    AppState.SpotlightActivation := mode
    ConfigManager.Save()

    key := mode == "hold"
        ? "MSG_SPOTLIGHT_ACTIVATION_HOLD"
        : "MSG_SPOTLIGHT_ACTIVATION_TOGGLE"
    fallback := mode == "hold"
        ? "Spotlight stays on while O is held."
        : "Spotlight toggles on and off with O."

    ShowToolTip(Lang(key, fallback), 2000)
}

; --- Always-on-top indicator (CapsLock + T) ---

; Master switch for the persistent pin badge. Toggling it on also picks up
; windows that were pinned while it was disabled, so the indicator never
; starts out out of sync with the real topmost state.
ToggleAlwaysOnTopIndicator(*) {
    next := !AppState.AlwaysOnTopIndicator
    PinIndicator.SetEnabled(next)

    key := next
        ? "MSG_TOPMOST_INDICATOR_ENABLED"
        : "MSG_TOPMOST_INDICATOR_DISABLED"
    fallback := next
        ? "Pinned windows show a pin badge."
        : "Pinned windows no longer show a pin badge."

    ShowToolTip(Lang(key, fallback), 2200)
}

; --- Window Switcher appearance (CapsLock + L) ---

SetWindowSwitcherIconSize(size, *) {
    if !_IsAllowedValue(size, AppState.WindowSwitcherIconSizes)
        return

    AppState.WindowSwitcherIconSize := size
    ConfigManager.Save()

    ShowToolTip(
        Lang("MSG_WS_ICON_SIZE_SET", "Window switcher icon size: {1} px.", size),
        1800
    )
}

SetWindowSwitcherDensity(mode, *) {
    mode := StrLower(mode)
    if !_IsAllowedValue(mode, AppState.WindowSwitcherDensities)
        return

    AppState.WindowSwitcherDensity := mode
    ConfigManager.Save()

    labels := Map(
        "compact", Lang("MENU_WS_DENSITY_COMPACT", "Compact"),
        "normal", Lang("MENU_WS_DENSITY_NORMAL", "Normal"),
        "spacious", Lang("MENU_WS_DENSITY_SPACIOUS", "Spacious")
    )

    ShowToolTip(
        Lang("MSG_WS_DENSITY_SET", "Window switcher row density: {1}.", labels[mode]),
        1800
    )
}

ToggleWindowSwitcherIcons(*) {
    AppState.WindowSwitcherShowIcons := !AppState.WindowSwitcherShowIcons
    ConfigManager.Save()

    key := AppState.WindowSwitcherShowIcons
        ? "MSG_WS_ICONS_ENABLED"
        : "MSG_WS_ICONS_DISABLED"
    fallback := AppState.WindowSwitcherShowIcons
        ? "The window switcher shows application icons."
        : "The window switcher hides application icons."

    ShowToolTip(Lang(key, fallback), 1800)
}

ToggleWindowSwitcherProcessColumn(*) {
    AppState.WindowSwitcherShowProcess := !AppState.WindowSwitcherShowProcess
    ConfigManager.Save()

    key := AppState.WindowSwitcherShowProcess
        ? "MSG_WS_PROCESS_ENABLED"
        : "MSG_WS_PROCESS_DISABLED"
    fallback := AppState.WindowSwitcherShowProcess
        ? "The window switcher shows the process column."
        : "The window switcher hides the process column."

    ShowToolTip(Lang(key, fallback), 1800)
}

ToggleWindowSwitcherHighlightRow(*) {
    AppState.WindowSwitcherHighlightRow := !AppState.WindowSwitcherHighlightRow
    ConfigManager.Save()

    key := AppState.WindowSwitcherHighlightRow
        ? "MSG_WS_HIGHLIGHT_ENABLED"
        : "MSG_WS_HIGHLIGHT_DISABLED"
    fallback := AppState.WindowSwitcherHighlightRow
        ? "The window switcher highlights the selected row."
        : "The window switcher uses the default row highlight."

    ShowToolTip(Lang(key, fallback), 1800)
}

_ParseWindowHoleRuleList(text) {
    result := []
    seen := Map()

    for line in StrSplit(text, Chr(10), Chr(13)) {
        value := Trim(line)
        if value == "" || InStr(value, "|")
            continue

        key := StrLower(value)
        if seen.Has(key)
            continue

        seen[key] := true
        result.Push(value)
    }

    return result
}
