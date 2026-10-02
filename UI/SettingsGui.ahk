#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Dedicated Google Workspace / Chrome Material Settings Center (SettingsGui)
;
; Consolidates all CapsLock- configuration into a multi-page Google Material
; settings interface with a left navigation rail, elevated surface cards,
; live theme/language switching, and instant persistence.
; ---------------------------------------------------------------------------

ShowSettingsGui(initialTab := 1, *) {
    SettingsGui.Show(initialTab)
}

class SettingsGui {
    static gui          := ""
    static activeTab    := 1
    static navButtons   := []
    static pageControls := Map()
    static headerTitle  := ""
    static headerDesc   := ""
    static statusText   := ""
    static controls     := Map()
    static langCodes    := []
    static pandocFormats := []

    static WIN_W := 900
    static WIN_H := 640
    static NAV_W := 220
    static CONTENT_X := 248
    static CONTENT_W := 624

    static IsOpen() {
        if !IsObject(this.gui)
            return false
        try {
            return WinExist("ahk_id " this.gui.Hwnd) ? true : false
        } catch {
            return false
        }
    }

    static Toggle() {
        if this.IsOpen() {
            this.Close()
            return
        }
        this.Show(this.activeTab)
    }

    static RefreshTheme() {
        if !this.IsOpen()
            return
        savedTab := this.activeTab
        try this.gui.Destroy()
        this.gui := ""
        this.Show(savedTab)
    }

    static Show(initialTab := 1) {
        if this.IsOpen() {
            try {
                if (initialTab >= 1 && initialTab <= 6 && initialTab != this.activeTab)
                    this.SwitchTab(initialTab)
                this.gui.Show()
                WinActivate("ahk_id " this.gui.Hwnd)
                return
            } catch {
                this.gui := ""
            }
        }

        if (initialTab < 1 || initialTab > 6)
            initialTab := 1
        this.activeTab := initialTab
        this.navButtons := []
        this.pageControls := Map(1, [], 2, [], 3, [], 4, [], 5, [], 6, [])
        this.controls := Map()

        myGui := Gui("+AlwaysOnTop -MaximizeBox", Lang("GUI_SETTINGS_TITLE"))
        ThemeHelper.StyleGui(myGui)
        myGui.MarginX := 0
        myGui.MarginY := 0

        ; --- Top Google 4-Color Brand Bar ---
        ThemeHelper.AddGoogleAccentBar(myGui, 0, 0, this.WIN_W, 3)

        ; --- Left Navigation Rail ---
        myGui.SetFont("s16 Bold c" AppState.THEME_ACCENT, AppState.THEME_FONT)
        brandTitle := myGui.Add("Text", "x20 y20 w184 h28 Background" AppState.THEME_BG, "CapsLock-")
        ThemeHelper.MarkSurface(brandTitle, AppState.THEME_ACCENT, AppState.THEME_BG)

        myGui.SetFont("s8 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        brandSub := myGui.Add(
            "Text",
            "x20 y48 w184 h18 Background" AppState.THEME_BG,
            Lang("GUI_SETTINGS_SUBTITLE")
        )
        ThemeHelper.MarkSurface(brandSub, AppState.THEME_FG_DIM, AppState.THEME_BG)

        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        navLabels := [
            "⚙️   " . Lang("SET_NAV_GENERAL"),
            "📋   " . Lang("SET_NAV_CLIPBOARD"),
            "🪟   " . Lang("SET_NAV_WINDOW"),
            "🔦   " . Lang("SET_NAV_VISUAL"),
            "☁   " . Lang("SET_NAV_INTEGRATION"),
            "⌨️   " . Lang("SET_NAV_TOOLS")
        ]

        navY := 78
        Loop navLabels.Length {
            idx := A_Index
            style := (idx == this.activeTab) ? "nav-active" : "nav"
            btn := ThemeHelper.AddButton(
                myGui,
                "x12 y" navY " w196 h38",
                navLabels[idx],
                style,
                AppState.THEME_BG
            )
            btn.OnEvent("Click", this._MakeTabCallback(idx))
            this.navButtons.Push(btn)
            navY += 44
        }

        ; --- Sidebar Footer Quick Theme Switcher Card ---
        ThemeHelper.AddSurfaceCard(myGui, 12, 560, 196, 64)
        myGui.SetFont("s8 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        themeHint := myGui.Add(
            "Text",
            "x24 y568 w172 h16 Background" AppState.THEME_SURFACE,
            Lang("MENU_THEME") . ": " . Theme.Label(Theme.Current)
        )
        ThemeHelper.MarkSurface(themeHint, AppState.THEME_FG_DIM, AppState.THEME_SURFACE)

        myGui.SetFont("s9 c" AppState.THEME_FG, AppState.THEME_FONT)
        quickThemeBtn := ThemeHelper.AddButton(
            myGui,
            "x22 y586 w176 h30",
            "🌓  " . Lang("MENU_THEME_DARK") . " / " . Lang("MENU_THEME_LIGHT"),
            "tonal",
            AppState.THEME_SURFACE
        )
        quickThemeBtn.OnEvent("Click", (*) => this._OnQuickThemeToggle())

        ; --- Vertical Hairline Divider between Sidebar and Content ---
        myGui.Add("Text", "x" this.NAV_W " y3 w1 h637 Background" AppState.THEME_BORDER)

        ; --- Content Page Header ---
        myGui.SetFont("s15 Bold c" AppState.THEME_FG, AppState.THEME_FONT)
        this.headerTitle := myGui.Add(
            "Text",
            "x" this.CONTENT_X " y20 w" this.CONTENT_W " h28 Background" AppState.THEME_BG,
            ""
        )
        ThemeHelper.MarkSurface(this.headerTitle, AppState.THEME_FG, AppState.THEME_BG)

        myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        this.headerDesc := myGui.Add(
            "Text",
            "x" this.CONTENT_X " y50 w" this.CONTENT_W " h20 Background" AppState.THEME_BG,
            ""
        )
        ThemeHelper.MarkSurface(this.headerDesc, AppState.THEME_FG_DIM, AppState.THEME_BG)

        myGui.Add("Text", "x" this.CONTENT_X " y76 w" this.CONTENT_W " h1 Background" AppState.THEME_BORDER)

        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; --- Build All 6 Settings Pages ---
        this._BuildPageGeneral(myGui)
        this._BuildPageClipboard(myGui)
        this._BuildPageWindow(myGui)
        this._BuildPageVisual(myGui)
        this._BuildPageIntegration(myGui)
        this._BuildPageTools(myGui)

        ; --- Bottom Sticky Action Bar ---
        myGui.Add("Text", "x221 y574 w679 h1 Background" AppState.THEME_BORDER)
        myGui.Add("Text", "x221 y575 w679 h65 Background" AppState.THEME_SURFACE)

        myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        this.statusText := myGui.Add(
            "Text",
            "x" this.CONTENT_X " y598 w350 h20 Background" AppState.THEME_SURFACE,
            Lang("SET_STATUS_READY")
        )
        ThemeHelper.MarkSurface(this.statusText, AppState.THEME_FG_DIM, AppState.THEME_SURFACE)

        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        saveBtn := ThemeHelper.AddButton(
            myGui,
            "Default x616 y590 w140 h34",
            "✓ " . Lang("SET_BTN_APPLY_ALL"),
            "primary",
            AppState.THEME_SURFACE
        )
        closeBtn := ThemeHelper.AddButton(
            myGui,
            "x766 y590 w106 h34",
            "✕ " . Lang("GUI_FULL_CLOSE"),
            "secondary",
            AppState.THEME_SURFACE
        )

        saveBtn.OnEvent("Click", (*) => this.ApplyAll(false))
        closeBtn.OnEvent("Click", (*) => this.Close())
        myGui.OnEvent("Escape", (*) => this.Close())
        myGui.OnEvent("Close", (*) => this.Close())

        this.gui := myGui
        AppState.SettingsGui := myGui

        ; Apply initial tab visibility before showing the window.
        this._UpdateTabVisibility(this.activeTab)

        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("w" this.WIN_W " h" this.WIN_H " Center")
    }

    static _MakeTabCallback(idx) {
        return (*) => this.SwitchTab(idx)
    }

    static _Reg(pageIdx, ctrl) {
        if IsObject(ctrl) {
            if (ctrl is Array) {
                for item in ctrl
                    this.pageControls[pageIdx].Push(item)
            } else {
                this.pageControls[pageIdx].Push(ctrl)
            }
        }
        return ctrl
    }

    static _AddSectionTitle(myGui, pageIdx, x, y, text) {
        myGui.SetFont("s10 Bold c" AppState.THEME_ACCENT, AppState.THEME_FONT)
        ctrl := myGui.Add("Text", "x" x " y" y " w" this.CONTENT_W " h20 Background" AppState.THEME_BG, text)
        ThemeHelper.MarkSurface(ctrl, AppState.THEME_ACCENT, AppState.THEME_BG)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        return this._Reg(pageIdx, ctrl)
    }

    static _AddCardLabel(myGui, pageIdx, x, y, w, text, isDim := false) {
        if isDim {
            myGui.SetFont("s8 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
            ctrl := myGui.Add("Text", "x" x " y" y " w" w " h18 Background" AppState.THEME_SURFACE, text)
            ThemeHelper.MarkSurface(ctrl, AppState.THEME_FG_DIM, AppState.THEME_SURFACE)
        } else {
            myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
            ctrl := myGui.Add("Text", "x" x " y" y " w" w " h22 Background" AppState.THEME_SURFACE, text)
            ThemeHelper.MarkSurface(ctrl, AppState.THEME_FG, AppState.THEME_SURFACE)
        }
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        return this._Reg(pageIdx, ctrl)
    }

    static _AddCardCheckBox(myGui, pageIdx, x, y, w, text, isChecked := false) {
        chk := myGui.Add(
            "CheckBox",
            "x" x " y" y " w" w " h24 " . ThemeHelper.GetCheckBoxOptions(, true),
            text
        )
        chk.Value := isChecked ? 1 : 0
        ThemeHelper.StyleCheckBox(chk, true)
        return this._Reg(pageIdx, chk)
    }

    static _AddCardEdit(myGui, pageIdx, x, y, w, val := "", extraOpts := "") {
        ed := myGui.Add(
            "Edit",
            "x" x " y" y " w" w " r1 " . ThemeHelper.GetEditOptions(extraOpts),
            String(val)
        )
        ThemeHelper.StyleEdit(ed)
        return this._Reg(pageIdx, ed)
    }

    static _AddCardCombo(myGui, pageIdx, x, y, w, items, selectedIdx := 1) {
        cbo := myGui.Add(
            "DropDownList",
            "x" x " y" y " w" w " Choose" selectedIdx " c" AppState.THEME_FG " Background" AppState.THEME_CONTROL_BG,
            items
        )
        ThemeHelper.StyleComboBox(cbo)
        return this._Reg(pageIdx, cbo)
    }

    static _AddCardButton(myGui, pageIdx, x, y, w, h, label, style := "secondary") {
        btn := ThemeHelper.AddButton(
            myGui,
            "x" x " y" y " w" w " h" h,
            label,
            style,
            AppState.THEME_SURFACE
        )
        return this._Reg(pageIdx, btn)
    }

    ; =======================================================================
    ; Page 1: General & Appearance
    ; =======================================================================
    static _BuildPageGeneral(myGui) {
        p := 1
        cx := this.CONTENT_X
        cw := this.CONTENT_W

        this._AddSectionTitle(myGui, p, cx, 92, Lang("SET_SEC_APPEARANCE"))
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 116, cw, 128))

        ; Row 1: Theme
        this._AddCardLabel(myGui, p, cx + 18, 132, 340, "🌓  " . Lang("MENU_THEME"))
        themeItems := [Lang("MENU_THEME_DARK"), Lang("MENU_THEME_LIGHT")]
        themeIdx := Theme.IsDark() ? 1 : 2
        cboTheme := this._AddCardCombo(myGui, p, cx + 410, 130, 194, themeItems, themeIdx)
        cboTheme.OnEvent("Change", (*) => this._OnThemeComboChange())
        this.controls["theme"] := cboTheme

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 178, cw))

        ; Row 2: Language
        this._AddCardLabel(myGui, p, cx + 18, 194, 260, "🌐  " . Lang("MENU_LANGUAGE"))
        this.langCodes := Language.GetLanguages()
        langLabels := []
        currLang := Language.GetCurrent()
        langIdx := 1
        Loop this.langCodes.Length {
            code := this.langCodes[A_Index]
            langLabels.Push(Lang("LANG_" . StrUpper(code), code))
            if (code == currLang)
                langIdx := A_Index
        }
        if langLabels.Length == 0 {
            this.langCodes := ["en", "zh"]
            langLabels := ["English", "中文 (简体)"]
        }
        cboLang := this._AddCardCombo(myGui, p, cx + 280, 192, 166, langLabels, langIdx)
        cboLang.OnEvent("Change", (*) => this._OnLangComboChange())
        this.controls["language"] := cboLang

        btnRebuildLang := this._AddCardButton(
            myGui, p, cx + 456, 190, 148, 28,
            "🔧 " . Lang("MENU_REBUILD_LANG")
        )
        btnRebuildLang.OnEvent("Click", (*) => RebuildLangCache())

        ; Section 2: System & Runtime
        this._AddSectionTitle(myGui, p, cx, 264, Lang("SET_SEC_SYSTEM"))
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 288, cw, 184))

        ; Row 1: AutoStart
        chkAutoStart := this._AddCardCheckBox(
            myGui, p, cx + 18, 304, 560,
            "🚀  " . Lang("MENU_AUTOSTART"),
            IsAutoStartEnabled()
        )
        this.controls["autoStart"] := chkAutoStart

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 344, cw))

        ; Row 2: Service Backend
        this._AddCardLabel(myGui, p, cx + 18, 360, 340, "⚡  " . Lang("SET_SEC_BACKEND"))
        backendIdx := (StrLower(AppState.ServiceBackend) == "csharp") ? 2 : 1
        cboBackend := this._AddCardCombo(
            myGui, p, cx + 410, 358, 194,
            ["AHK Native (ahk)", "C# CLR (csharp)"],
            backendIdx
        )
        this.controls["serviceBackend"] := cboBackend

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 404, cw))

        ; Row 3: Quick System Folders
        btnOpenTemp := this._AddCardButton(
            myGui, p, cx + 18, 420, 220, 32,
            "📂 " . Lang("MENU_OPEN_TEMP")
        )
        btnOpenTemp.OnEvent("Click", (*) => OpenTempFolder())

        btnOpenCfg := this._AddCardButton(
            myGui, p, cx + 250, 420, 220, 32,
            "📁 " . Lang("SET_BTN_OPEN_CONFIG")
        )
        btnOpenCfg.OnEvent("Click", (*) => Run("explore " . A_ScriptDir . "\configs"))
    }

    ; =======================================================================
    ; Page 2: Clipboard & History
    ; =======================================================================
    static _BuildPageClipboard(myGui) {
        p := 2
        cx := this.CONTENT_X
        cw := this.CONTENT_W

        this._AddSectionTitle(myGui, p, cx, 92, Lang("SET_SEC_HISTORY"))
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 116, cw, 228))

        ; Row 1: Paste Mode
        this._AddCardLabel(myGui, p, cx + 18, 132, 320, "📋  " . Lang("MENU_PASTE_MODE"))
        pasteIdx := (AppState.PasteMode == 2) ? 2 : 1
        cboPaste := this._AddCardCombo(
            myGui, p, cx + 354, 130, 250,
            [Lang("MENU_PASTE_FILE"), Lang("MENU_PASTE_TEXT")],
            pasteIdx
        )
        this.controls["pasteMode"] := cboPaste

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 174, cw))

        ; Row 2: Max History + Open Full History
        this._AddCardLabel(myGui, p, cx + 18, 190, 290, "📝  " . Lang("INPUT_MAX_HISTORY_TITLE"))
        edMaxHist := this._AddCardEdit(myGui, p, cx + 354, 188, 96, AppState.MaxHistory, "Number")
        this.controls["maxHistory"] := edMaxHist

        btnFullHist := this._AddCardButton(
            myGui, p, cx + 460, 186, 144, 28,
            "📋 " . Lang("GUI_FULL_TITLE")
        )
        btnFullHist.OnEvent("Click", (*) => ShowFullHistoryGui())

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 230, cw))

        ; Row 3: Auto-Clean History + Max Retained Items
        chkAutoClean := this._AddCardCheckBox(
            myGui, p, cx + 18, 244, 320,
            Lang("SET_LBL_AUTO_CLEAN"),
            AppState.AutoCleanEnabled
        )
        this.controls["autoClean"] := chkAutoClean

        this._AddCardLabel(myGui, p, cx + 354, 246, 150, Lang("SET_LBL_MAX_ITEMS"), true)
        edMaxItems := this._AddCardEdit(myGui, p, cx + 508, 244, 96, AppState.MaxHistoryItems, "Number")
        this.controls["maxHistoryItems"] := edMaxItems

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 286, cw))

        ; Row 4: Ignore Rules
        this._AddCardLabel(
            myGui, p, cx + 18, 302, 360,
            "🚫  " . Lang("GUI_IGNORE_TITLE") . " (" . AppState.IgnorePatterns.Length . ")"
        )
        btnIgnore := this._AddCardButton(
            myGui, p, cx + 410, 298, 194, 30,
            "🚫 " . Lang("MENU_IGNORE_RULES")
        )
        btnIgnore.OnEvent("Click", (*) => SetIgnorePatterns())

        ; Section 2: Temporary File Cleanup
        this._AddSectionTitle(myGui, p, cx, 362, Lang("SET_SEC_CLEANUP"))
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 386, cw, 128))

        ; Row 1: Delete Mode
        this._AddCardLabel(myGui, p, cx + 18, 402, 320, "🧹  " . Lang("MENU_DELETE_MODE"))
        delIdx := Clamp(Integer(AppState.DeleteMode), 1, 3)
        cboDelete := this._AddCardCombo(
            myGui, p, cx + 354, 400, 250,
            [Lang("MENU_MODE1"), Lang("MENU_MODE2"), Lang("MENU_MODE3")],
            delIdx
        )
        this.controls["deleteMode"] := cboDelete

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 446, cw))

        ; Row 2: Delete Delay & Cleanup Interval
        this._AddCardLabel(myGui, p, cx + 18, 464, 190, "⏱️  " . Lang("SET_LBL_DELAY_SEC"))
        edDelay := this._AddCardEdit(myGui, p, cx + 214, 462, 80, AppState.DeleteDelay, "Number")
        this.controls["deleteDelay"] := edDelay

        this._AddCardLabel(myGui, p, cx + 318, 464, 196, "🔄  " . Lang("SET_LBL_INTERVAL_SEC"))
        edInterval := this._AddCardEdit(myGui, p, cx + 524, 462, 80, AppState.CleanupInterval, "Number")
        this.controls["cleanupInterval"] := edInterval
    }

    ; =======================================================================
    ; Page 3: Window & Switcher
    ; =======================================================================
    static _BuildPageWindow(myGui) {
        p := 3
        cx := this.CONTENT_X
        cw := this.CONTENT_W

        ; Section 1: Pinned & Hidden Windows
        this._AddSectionTitle(myGui, p, cx, 92, Lang("SET_SEC_TOPMOST"))
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 116, cw, 64))

        chkPinBadge := this._AddCardCheckBox(
            myGui, p, cx + 18, 134, 370,
            "📌  " . Lang("MENU_TOPMOST_INDICATOR"),
            AppState.AlwaysOnTopIndicator
        )
        this.controls["topmostIndicator"] := chkPinBadge

        btnRestoreHidden := this._AddCardButton(
            myGui, p, cx + 404, 131, 200, 30,
            "🫥 " . Lang("MENU_HIDDEN_RESTORE_ALL") . " (" . TrayHider.Count() . ")"
        )
        btnRestoreHidden.OnEvent("Click", (*) => TrayHider.RestoreAll(true))

        ; Section 2: Window Switcher (CapsLock + L)
        this._AddSectionTitle(myGui, p, cx, 196, Lang("MENU_WINDOW_SWITCHER") . " (CapsLock + L)")
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 220, cw, 134))

        chkWsIcons := this._AddCardCheckBox(
            myGui, p, cx + 18, 234, 280,
            Lang("MENU_WS_ICONS"),
            AppState.WindowSwitcherShowIcons
        )
        this.controls["wsShowIcons"] := chkWsIcons

        this._AddCardLabel(myGui, p, cx + 310, 236, 130, Lang("MENU_WS_ICON_SIZE"))
        wsSizes := ["16 px", "20 px", "24 px", "32 px"]
        wsSizeIdx := 3
        Loop AppState.WindowSwitcherIconSizes.Length {
            if (AppState.WindowSwitcherIconSizes[A_Index] == AppState.WindowSwitcherIconSize)
                wsSizeIdx := A_Index
        }
        cboWsSize := this._AddCardCombo(myGui, p, cx + 450, 232, 154, wsSizes, wsSizeIdx)
        this.controls["wsIconSize"] := cboWsSize

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 272, cw))

        chkWsProc := this._AddCardCheckBox(
            myGui, p, cx + 18, 286, 190,
            Lang("MENU_WS_PROCESS"),
            AppState.WindowSwitcherShowProcess
        )
        this.controls["wsShowProcess"] := chkWsProc

        chkWsHi := this._AddCardCheckBox(
            myGui, p, cx + 214, 286, 190,
            Lang("MENU_WS_HIGHLIGHT"),
            AppState.WindowSwitcherHighlightRow
        )
        this.controls["wsHighlight"] := chkWsHi

        wsDensIdx := (AppState.WindowSwitcherDensity == "compact")
            ? 1
            : (AppState.WindowSwitcherDensity == "spacious" ? 3 : 2)
        cboWsDensity := this._AddCardCombo(
            myGui, p, cx + 450, 284, 154,
            [
                Lang("MENU_WS_DENSITY_COMPACT"),
                Lang("MENU_WS_DENSITY_NORMAL"),
                Lang("MENU_WS_DENSITY_SPACIOUS")
            ],
            wsDensIdx
        )
        this.controls["wsDensity"] := cboWsDensity

        ; Section 3: Window Hole (CapsLock + X)
        this._AddSectionTitle(myGui, p, cx, 370, Lang("MENU_WINDOW_HOLE") . " (CapsLock + X)")
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 394, cw, 158))

        this._AddCardLabel(myGui, p, cx + 18, 410, 170, "📏  " . Lang("MENU_WINDOW_HOLE_SIZE") . " (px)")
        edHoleSize := this._AddCardEdit(myGui, p, cx + 196, 408, 84, AppState.WindowHoleDiameter, "Number")
        this.controls["holeDiameter"] := edHoleSize

        this._AddCardLabel(myGui, p, cx + 304, 410, 130, Lang("MENU_WINDOW_HOLE_SHAPE"))
        holeShapeIdx := (AppState.WindowHoleShape == "rounded")
            ? 2
            : (AppState.WindowHoleShape == "square" ? 3 : 1)
        cboHoleShape := this._AddCardCombo(
            myGui, p, cx + 440, 406, 164,
            [
                Lang("MENU_WINDOW_HOLE_SHAPE_CIRCLE"),
                Lang("MENU_WINDOW_HOLE_SHAPE_ROUNDED"),
                Lang("MENU_WINDOW_HOLE_SHAPE_SQUARE")
            ],
            holeShapeIdx
        )
        this.controls["holeShape"] := cboHoleShape

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 450, cw))

        this._AddCardLabel(myGui, p, cx + 18, 466, 170, "⌨️  " . Lang("MENU_WINDOW_HOLE_ACTIVATION"))
        holeActIdx := (AppState.WindowHoleActivation == "toggle") ? 2 : 1
        cboHoleAct := this._AddCardCombo(
            myGui, p, cx + 196, 462, 190,
            [Lang("MENU_WINDOW_HOLE_HOLD"), Lang("MENU_WINDOW_HOLE_TOGGLE")],
            holeActIdx
        )
        this.controls["holeActivation"] := cboHoleAct

        btnHoleRules := this._AddCardButton(
            myGui, p, cx + 440, 460, 164, 30,
            "⚙️ " . Lang("MENU_WINDOW_HOLE_RULES")
        )
        btnHoleRules.OnEvent("Click", (*) => SetWindowHoleRules())

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 504, cw))

        chkHoleFallback := this._AddCardCheckBox(
            myGui, p, cx + 18, 516, 560,
            Lang("MENU_WINDOW_HOLE_FALLBACK"),
            AppState.WindowHoleFallbackToMinimize
        )
        this.controls["holeFallback"] := chkHoleFallback
    }

    ; =======================================================================
    ; Page 4: Spotlight & Zoom
    ; =======================================================================
    static _BuildPageVisual(myGui) {
        p := 4
        cx := this.CONTENT_X
        cw := this.CONTENT_W

        ; Section 1: Spotlight (CapsLock + O)
        this._AddSectionTitle(myGui, p, cx, 92, "🔦  " . Lang("MENU_SPOTLIGHT") . " (CapsLock + O)")
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 116, cw, 184))

        this._AddCardLabel(myGui, p, cx + 18, 134, 180, "📏  " . Lang("MENU_SPOTLIGHT_RADIUS") . " (40-900)")
        edSpotRadius := this._AddCardEdit(myGui, p, cx + 206, 132, 84, AppState.SpotlightRadius, "Number")
        this.controls["spotRadius"] := edSpotRadius

        this._AddCardLabel(myGui, p, cx + 314, 134, 190, "🌫  " . Lang("MENU_SPOTLIGHT_SOFTNESS") . " (0-250)")
        edSpotSoft := this._AddCardEdit(myGui, p, cx + 520, 132, 84, AppState.SpotlightSoftness, "Number")
        this.controls["spotSoftness"] := edSpotSoft

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 176, cw))

        this._AddCardLabel(myGui, p, cx + 18, 194, 180, "🌙  " . Lang("MENU_SPOTLIGHT_DARKNESS") . " (5-95%)")
        edSpotDark := this._AddCardEdit(myGui, p, cx + 206, 192, 84, AppState.SpotlightDarkness, "Number")
        this.controls["spotDarkness"] := edSpotDark

        this._AddCardLabel(myGui, p, cx + 314, 194, 120, Lang("MENU_SPOTLIGHT_SHAPE"))
        spotShapeIdx := (AppState.SpotlightShape == "rounded")
            ? 2
            : (AppState.SpotlightShape == "square" ? 3 : 1)
        cboSpotShape := this._AddCardCombo(
            myGui, p, cx + 440, 190, 164,
            [
                Lang("MENU_SPOTLIGHT_SHAPE_CIRCLE"),
                Lang("MENU_SPOTLIGHT_SHAPE_ROUNDED"),
                Lang("MENU_SPOTLIGHT_SHAPE_SQUARE")
            ],
            spotShapeIdx
        )
        this.controls["spotShape"] := cboSpotShape

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 236, cw))

        this._AddCardLabel(myGui, p, cx + 18, 254, 180, "⌨️  " . Lang("MENU_SPOTLIGHT_ACTIVATION"))
        spotActIdx := (AppState.SpotlightActivation == "hold") ? 1 : 2
        cboSpotAct := this._AddCardCombo(
            myGui, p, cx + 206, 250, 190,
            [Lang("MENU_SPOTLIGHT_ACTIVATION_HOLD"), Lang("MENU_SPOTLIGHT_ACTIVATION_TOGGLE")],
            spotActIdx
        )
        this.controls["spotActivation"] := cboSpotAct

        btnTestSpot := this._AddCardButton(
            myGui, p, cx + 420, 248, 184, 30,
            "🔦 " . Lang("MENU_SPOTLIGHT_TOGGLE"),
            "tonal"
        )
        btnTestSpot.OnEvent("Click", (*) => (this.ApplyAll(true), Spotlight.Toggle()))

        ; Section 2: Dynamic Zoom (CapsLock + Z)
        this._AddSectionTitle(myGui, p, cx, 322, "🔎  " . Lang("MENU_ZOOM") . " (CapsLock + Z)")
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 346, cw, 124))

        this._AddCardLabel(myGui, p, cx + 18, 364, 240, "🔍  " . Lang("MENU_ZOOM_FACTOR") . " (2x - 16x)")
        edZoomFactor := this._AddCardEdit(myGui, p, cx + 270, 362, 84, AppState.ZoomFactor, "Number")
        this.controls["zoomFactor"] := edZoomFactor

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 406, cw))

        this._AddCardLabel(myGui, p, cx + 18, 424, 180, "⌨️  " . Lang("MENU_ZOOM_ACTIVATION"))
        zoomActIdx := (AppState.ZoomActivation == "hold") ? 1 : 2
        cboZoomAct := this._AddCardCombo(
            myGui, p, cx + 206, 420, 190,
            [Lang("MENU_ZOOM_ACTIVATION_HOLD"), Lang("MENU_ZOOM_ACTIVATION_TOGGLE")],
            zoomActIdx
        )
        this.controls["zoomActivation"] := cboZoomAct

        btnTestZoom := this._AddCardButton(
            myGui, p, cx + 420, 418, 184, 30,
            "🔎 " . Lang("MENU_ZOOM_TOGGLE"),
            "tonal"
        )
        btnTestZoom.OnEvent("Click", (*) => (this.ApplyAll(true), Zoom.Toggle()))
    }

    ; =======================================================================
    ; Page 5: Phrases & Cloud Sync
    ; =======================================================================
    static _BuildPageIntegration(myGui) {
        p := 5
        cx := this.CONTENT_X
        cw := this.CONTENT_W

        ; Section 1: Quick Phrases (CapsLock + Shift + P)
        this._AddSectionTitle(myGui, p, cx, 92, "💬  " . Lang("MENU_QUICK_PHRASE") . " (CapsLock + Shift + P)")
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 116, cw, 124))

        chkQp := this._AddCardCheckBox(
            myGui, p, cx + 18, 132, 360,
            Lang("MENU_QUICK_PHRASE_ENABLE"),
            AppState.QuickPhraseEnabled
        )
        this.controls["quickPhraseEnabled"] := chkQp

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 174, cw))

        qpCount := QuickPhraseStore.GetAll().Length
        this._AddCardLabel(
            myGui, p, cx + 18, 192, 340,
            Lang("GUI_QUICK_PHRASE_STATUS", "{1} quick phrase(s) available.", qpCount)
        )
        btnManageQp := this._AddCardButton(
            myGui, p, cx + 410, 188, 194, 30,
            "📝 " . Lang("MENU_QUICK_PHRASE_MANAGE"),
            "primary"
        )
        btnManageQp.OnEvent("Click", (*) => ShowQuickPhraseManager())

        ; Section 2: Cloud Sync
        this._AddSectionTitle(myGui, p, cx, 260, "☁  " . Lang("GUI_CLOUD_SYNC_TITLE"))
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 284, cw, 194))

        chkCloud := this._AddCardCheckBox(
            myGui, p, cx + 18, 300, 320,
            Lang("GUI_CLOUD_SYNC_ENABLE"),
            AppState.CloudSyncEnabled
        )
        this.controls["cloudSyncEnabled"] := chkCloud

        this._AddCardLabel(
            myGui, p, cx + 350, 302, 254,
            CloudSyncCoordinator.GetStatusText(),
            true
        )

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 342, cw))

        chkCloudAuto := this._AddCardCheckBox(
            myGui, p, cx + 18, 358, 330,
            Lang("GUI_CLOUD_SYNC_AUTO"),
            AppState.CloudSyncAutoEnabled
        )
        this.controls["cloudSyncAuto"] := chkCloudAuto

        this._AddCardLabel(myGui, p, cx + 360, 360, 130, Lang("GUI_CLOUD_SYNC_INTERVAL") . " (" . Lang("GUI_CLOUD_SYNC_MINUTES") . ")")
        edCloudInt := this._AddCardEdit(myGui, p, cx + 520, 358, 84, AppState.CloudSyncInterval, "Number")
        this.controls["cloudSyncInterval"] := edCloudInt

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 404, cw))

        btnCloudCfg := this._AddCardButton(
            myGui, p, cx + 18, 424, 210, 32,
            "⚙️ " . Lang("MENU_CLOUD_SYNC_SETTINGS"),
            "primary"
        )
        btnCloudCfg.OnEvent("Click", (*) => ShowCloudSyncSettings())

        btnCloudNow := this._AddCardButton(
            myGui, p, cx + 238, 424, 180, 32,
            "☁ " . Lang("MENU_CLOUD_SYNC_NOW"),
            "tonal"
        )
        btnCloudNow.OnEvent("Click", (*) => CloudSyncCoordinator.SyncNow())

        btnCloudDisc := this._AddCardButton(
            myGui, p, cx + 428, 424, 176, 32,
            "🔌 " . Lang("MENU_CLOUD_SYNC_DISCONNECT")
        )
        btnCloudDisc.OnEvent("Click", (*) => CloudSyncCoordinator.Disconnect())
    }

    ; =======================================================================
    ; Page 6: Tools & Shortcuts
    ; =======================================================================
    static _BuildPageTools(myGui) {
        p := 6
        cx := this.CONTENT_X
        cw := this.CONTENT_W

        ; Section 1: External Tools
        this._AddSectionTitle(myGui, p, cx, 92, Lang("SET_SEC_EXTERNAL"))
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 116, cw, 194))

        ; Row 1: ImageMagick
        imValid := AppState.ImageMagickExe != ""
            && InStr(StrLower(AppState.ImageMagickExe), "magick.exe")
            && FileExist(AppState.ImageMagickExe)
        imTitle := imValid ? "📦  " . Lang("MENU_IM_STATUS_SET") : "📦  " . Lang("MENU_IM_STATUS_NOTSET")
        this._AddCardLabel(myGui, p, cx + 18, 130, 580, imTitle)

        edImPath := this._AddCardEdit(myGui, p, cx + 18, 154, 462, AppState.ImageMagickExe, "ReadOnly")
        this.controls["imPath"] := edImPath
        btnImBrowse := this._AddCardButton(
            myGui, p, cx + 490, 152, 114, 28,
            "📂 " . Lang("SET_BTN_BROWSE")
        )
        btnImBrowse.OnEvent("Click", (*) => (SetImPath(), edImPath.Value := AppState.ImageMagickExe))

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 192, cw))

        ; Row 2: Pandoc Path
        pandocValid := AppState.PandocExe != "" && FileExist(AppState.PandocExe)
        pandocTitle := pandocValid ? "📄  " . Lang("MENU_PANDOC_STATUS_SET") : "📄  " . Lang("MENU_PANDOC_STATUS_NOTSET")
        this._AddCardLabel(myGui, p, cx + 18, 204, 580, pandocTitle)

        edPandocPath := this._AddCardEdit(myGui, p, cx + 18, 228, 462, AppState.PandocExe, "ReadOnly")
        this.controls["pandocPath"] := edPandocPath
        btnPandocBrowse := this._AddCardButton(
            myGui, p, cx + 490, 226, 114, 28,
            "📂 " . Lang("SET_BTN_BROWSE")
        )
        btnPandocBrowse.OnEvent("Click", (*) => (SetPandocPath(), edPandocPath.Value := AppState.PandocExe))

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 266, cw))

        ; Row 3: Pandoc Output Format
        this._AddCardLabel(myGui, p, cx + 18, 278, 360, "📤  " . Lang("INPUT_PANDOC_OUTPUT_TITLE"))
        this.pandocFormats := AppState.PandocOutputFormats.Clone()
        _SortStrings(this.pandocFormats)
        fmtIdx := 1
        Loop this.pandocFormats.Length {
            if (this.pandocFormats[A_Index] == AppState.PandocOutputFormat) {
                fmtIdx := A_Index
                break
            }
        }
        cboPandocFmt := this._AddCardCombo(myGui, p, cx + 420, 274, 184, this.pandocFormats, fmtIdx)
        this.controls["pandocFormat"] := cboPandocFmt

        ; Section 2: Shortcuts & Application Control
        this._AddSectionTitle(myGui, p, cx, 330, Lang("SET_SEC_SHORTCUTS"))
        this._Reg(p, ThemeHelper.AddSurfaceCard(myGui, cx, 354, cw, 124))

        this._AddCardLabel(myGui, p, cx + 18, 372, 360, "⌨️  " . Lang("CHEAT_TITLE") . " (CapsLock + H / F1)")
        btnCheat := this._AddCardButton(
            myGui, p, cx + 410, 368, 194, 30,
            "⌨️ " . Lang("MENU_CHEATSHEET"),
            "primary"
        )
        btnCheat.OnEvent("Click", (*) => OpenCheatsheetFromTray())

        this._Reg(p, ThemeHelper.AddCardDivider(myGui, cx, 414, cw))

        btnReload := this._AddCardButton(
            myGui, p, cx + 18, 430, 190, 32,
            "🔄 " . Lang("MENU_RELOAD")
        )
        btnReload.OnEvent("Click", (*) => ReloadWithRestore())

        btnExit := this._AddCardButton(
            myGui, p, cx + 220, 430, 190, 32,
            "❌ " . Lang("MENU_EXIT"),
            "danger"
        )
        btnExit.OnEvent("Click", (*) => ExitWithRestore())
    }

    ; =======================================================================
    ; Navigation & State Persistence
    ; =======================================================================
    static SwitchTab(tabIdx) {
        if !this.IsOpen()
            return
        if (tabIdx < 1 || tabIdx > 6 || tabIdx == this.activeTab)
            return

        this.activeTab := tabIdx
        SendMessage(0x000B, 0, 0, this.gui.Hwnd)
        this._UpdateTabVisibility(tabIdx)
        SendMessage(0x000B, 1, 0, this.gui.Hwnd)
        DllCall("user32\InvalidateRect", "Ptr", this.gui.Hwnd, "Ptr", 0, "Int", 1)
    }

    static _UpdateTabVisibility(tabIdx) {
        titles := [
            Lang("SET_NAV_GENERAL"),
            Lang("SET_NAV_CLIPBOARD"),
            Lang("SET_NAV_WINDOW"),
            Lang("SET_NAV_VISUAL"),
            Lang("SET_NAV_INTEGRATION"),
            Lang("SET_NAV_TOOLS")
        ]
        descs := [
            Lang("SET_DESC_GENERAL"),
            Lang("SET_DESC_CLIPBOARD"),
            Lang("SET_DESC_WINDOW"),
            Lang("SET_DESC_VISUAL"),
            Lang("SET_DESC_INTEGRATION"),
            Lang("SET_DESC_TOOLS")
        ]

        if IsObject(this.headerTitle)
            this.headerTitle.Text := titles[tabIdx]
        if IsObject(this.headerDesc)
            this.headerDesc.Text := descs[tabIdx]

        Loop this.navButtons.Length {
            idx := A_Index
            ThemeHelper.SetButtonStyle(
                this.navButtons[idx],
                idx == tabIdx ? "nav-active" : "nav",
                AppState.THEME_BG
            )
        }

        for pageIdx, ctrlList in this.pageControls {
            showPage := (pageIdx == tabIdx)
            for ctrl in ctrlList {
                try ctrl.Visible := showPage
            }
        }
    }

    static _OnQuickThemeToggle() {
        this.ApplyAll(true)
        Theme.Toggle()
    }

    static _OnThemeComboChange() {
        if !this.controls.Has("theme")
            return
        idx := this.controls["theme"].Value
        targetMode := (idx == 2) ? Theme.Light : Theme.Dark
        if (targetMode != Theme.Current) {
            this.ApplyAll(true)
            Theme.Set(targetMode)
        }
    }

    static _OnLangComboChange() {
        if !this.controls.Has("language")
            return
        idx := this.controls["language"].Value
        if (idx >= 1 && idx <= this.langCodes.Length) {
            code := this.langCodes[idx]
            if (code != Language.GetCurrent()) {
                this.ApplyAll(true)
                SwitchLanguage(code)
                this.RefreshTheme()
            }
        }
    }

    static ApplyAll(silent := false) {
        if !this.IsOpen()
            return

        c := this.controls

        ; --- 1. General & Appearance ---
        if c.Has("autoStart") {
            wantAuto := c["autoStart"].Value == 1
            if (wantAuto != IsAutoStartEnabled())
                ToggleAutoStart()
        }

        if c.Has("serviceBackend") {
            AppState.ServiceBackend := (c["serviceBackend"].Value == 2) ? "csharp" : "ahk"
            Services.Configure()
        }

        ; --- 2. Clipboard & History ---
        if c.Has("pasteMode") {
            AppState.PasteMode := (c["pasteMode"].Value == 2) ? 2 : 1
        }

        if c.Has("maxHistory") && IsNumber(c["maxHistory"].Value) {
            newMax := Max(0, Integer(c["maxHistory"].Value))
            AppState.MaxHistory := newMax
            HistoryManager.Trim(AppState.MaxHistory)
            HistoryManager.ForceSave()
        }

        if c.Has("autoClean") {
            prevAutoClean := AppState.AutoCleanEnabled
            AppState.AutoCleanEnabled := (c["autoClean"].Value == 1)
            if (AppState.AutoCleanEnabled != prevAutoClean)
                SetTimer(AutoCleanHistory, AppState.AutoCleanEnabled ? 60000 : 0)
        }

        if c.Has("maxHistoryItems") && IsNumber(c["maxHistoryItems"].Value) {
            AppState.MaxHistoryItems := Max(10, Integer(c["maxHistoryItems"].Value))
        }

        if c.Has("deleteMode") {
            AppState.DeleteMode := Clamp(c["deleteMode"].Value, 1, 3)
        }

        if c.Has("deleteDelay") && IsNumber(c["deleteDelay"].Value) {
            AppState.DeleteDelay := Max(1, Integer(c["deleteDelay"].Value))
        }

        if c.Has("cleanupInterval") && IsNumber(c["cleanupInterval"].Value) {
            AppState.CleanupInterval := Max(1, Integer(c["cleanupInterval"].Value))
        }

        ; --- 3. Window & Switcher ---
        if c.Has("topmostIndicator") {
            wantBadge := (c["topmostIndicator"].Value == 1)
            if (wantBadge != AppState.AlwaysOnTopIndicator)
                PinIndicator.SetEnabled(wantBadge)
        }

        if c.Has("wsShowIcons")
            AppState.WindowSwitcherShowIcons := (c["wsShowIcons"].Value == 1)

        if c.Has("wsIconSize") {
            idx := Clamp(c["wsIconSize"].Value, 1, AppState.WindowSwitcherIconSizes.Length)
            AppState.WindowSwitcherIconSize := AppState.WindowSwitcherIconSizes[idx]
        }

        if c.Has("wsShowProcess")
            AppState.WindowSwitcherShowProcess := (c["wsShowProcess"].Value == 1)

        if c.Has("wsHighlight")
            AppState.WindowSwitcherHighlightRow := (c["wsHighlight"].Value == 1)

        if c.Has("wsDensity") {
            idx := Clamp(c["wsDensity"].Value, 1, AppState.WindowSwitcherDensities.Length)
            AppState.WindowSwitcherDensity := AppState.WindowSwitcherDensities[idx]
        }

        if c.Has("holeDiameter") && IsNumber(c["holeDiameter"].Value) {
            AppState.WindowHoleDiameter := Clamp(Integer(c["holeDiameter"].Value), 80, 1200)
            c["holeDiameter"].Value := String(AppState.WindowHoleDiameter)
        }

        if c.Has("holeShape") {
            shapes := ["circle", "rounded", "square"]
            AppState.WindowHoleShape := shapes[Clamp(c["holeShape"].Value, 1, 3)]
        }

        if c.Has("holeActivation") {
            AppState.WindowHoleActivation := (c["holeActivation"].Value == 2) ? "toggle" : "hold"
        }

        if c.Has("holeFallback") {
            AppState.WindowHoleFallbackToMinimize := (c["holeFallback"].Value == 1)
        }

        ; --- 4. Spotlight & Zoom ---
        if c.Has("spotRadius") && IsNumber(c["spotRadius"].Value) {
            AppState.SpotlightRadius := Clamp(Integer(c["spotRadius"].Value), 40, 900)
            c["spotRadius"].Value := String(AppState.SpotlightRadius)
        }

        if c.Has("spotSoftness") && IsNumber(c["spotSoftness"].Value) {
            AppState.SpotlightSoftness := Clamp(Integer(c["spotSoftness"].Value), 0, 250)
            c["spotSoftness"].Value := String(AppState.SpotlightSoftness)
        }

        if c.Has("spotDarkness") && IsNumber(c["spotDarkness"].Value) {
            AppState.SpotlightDarkness := Clamp(Integer(c["spotDarkness"].Value), 5, 95)
            c["spotDarkness"].Value := String(AppState.SpotlightDarkness)
        }

        if c.Has("spotShape") {
            shapes := ["circle", "rounded", "square"]
            AppState.SpotlightShape := shapes[Clamp(c["spotShape"].Value, 1, 3)]
        }

        if c.Has("spotActivation") {
            AppState.SpotlightActivation := (c["spotActivation"].Value == 1) ? "hold" : "toggle"
        }

        Spotlight.Refresh()

        if c.Has("zoomFactor") && IsNumber(c["zoomFactor"].Value) {
            AppState.ZoomFactor := Clamp(Integer(c["zoomFactor"].Value), 2, 16)
            c["zoomFactor"].Value := String(AppState.ZoomFactor)
        }

        if c.Has("zoomActivation") {
            AppState.ZoomActivation := (c["zoomActivation"].Value == 1) ? "hold" : "toggle"
        }

        Zoom.Refresh()

        ; --- 5. Phrases & Cloud Sync ---
        if c.Has("quickPhraseEnabled") {
            AppState.QuickPhraseEnabled := (c["quickPhraseEnabled"].Value == 1)
        }

        if c.Has("cloudSyncEnabled") {
            AppState.CloudSyncEnabled := (c["cloudSyncEnabled"].Value == 1)
        }

        if c.Has("cloudSyncAuto") {
            AppState.CloudSyncAutoEnabled := (c["cloudSyncAuto"].Value == 1)
        }

        if c.Has("cloudSyncInterval") && IsNumber(c["cloudSyncInterval"].Value) {
            AppState.CloudSyncInterval := Clamp(Integer(c["cloudSyncInterval"].Value), 5, 1440)
            c["cloudSyncInterval"].Value := String(AppState.CloudSyncInterval)
        }

        if !AppState.CloudSyncEnabled {
            CloudSyncCoordinator.StopAutoSync()
            CloudSyncState.Set("Sync", "state", "disabled")
        } else if AppState.CloudSyncAutoEnabled {
            CloudSyncCoordinator.StartAutoSync()
        }

        ; --- 6. Tools ---
        if c.Has("pandocFormat") {
            idx := c["pandocFormat"].Value
            if (idx >= 1 && idx <= this.pandocFormats.Length)
                AppState.PandocOutputFormat := this.pandocFormats[idx]
        }

        ConfigManager.Save()

        if !silent {
            if IsObject(this.statusText)
                this.statusText.Text := "✓ " . Lang("SET_STATUS_SAVED")
            OSD.ShowNotification(Lang("SET_STATUS_SAVED"), 1600, "success")
        }
    }

    static Close() {
        if IsObject(this.gui) {
            try this.gui.Destroy()
        }
        this.gui := ""
        this.navButtons := []
        this.pageControls := Map()
        this.controls := Map()
        AppState.SettingsGui := ""
    }
}
