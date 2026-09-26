#Requires AutoHotkey v2.0

; Central theme controller.
;
; Theme values live in AppState.THEME_PALETTES (Config/Globals.ahk). This class
; owns "which palette is active" and copies it into the AppState.THEME_* fields
; every shared UI component already reads. Windows therefore never need to know
; which theme is selected; they only read the current THEME_* values.
class Theme {
    static Dark   := "dark"
    static Light  := "light"
    static Modes  := ["dark", "light"]
    static Default := "dark"

    static Current := "dark"

    static Normalize(mode) {
        mode := StrLower(Trim(String(mode)))
        for candidate in this.Modes {
            if candidate == mode
                return mode
        }
        return this.Default
    }

    static IsDark() => this.Current == this.Dark

    static IsValid(mode) {
        mode := StrLower(Trim(String(mode)))
        for candidate in this.Modes {
            if candidate == mode
                return true
        }
        return false
    }

    ; Copy a palette into the shared THEME_* fields.
    static Apply(mode := "") {
        if (mode == "")
            mode := this.Current

        mode := this.Normalize(mode)

        palette := AppState.THEME_PALETTES.Has(mode)
            ? AppState.THEME_PALETTES[mode]
            : AppState.THEME_PALETTES[this.Default]

        AppState.THEME_BG            := palette["THEME_BG"]
        AppState.THEME_SURFACE       := palette["THEME_SURFACE"]
        AppState.THEME_ELEVATED      := palette["THEME_ELEVATED"]
        AppState.THEME_CONTROL_BG    := palette["THEME_CONTROL_BG"]
        AppState.THEME_CONTROL_HOVER := palette["THEME_CONTROL_HOVER"]
        AppState.THEME_BORDER        := palette["THEME_BORDER"]

        AppState.THEME_FG            := palette["THEME_FG"]
        AppState.THEME_FG_DIM        := palette["THEME_FG_DIM"]
        AppState.THEME_FG_MUTED      := palette["THEME_FG_MUTED"]

        AppState.THEME_ACCENT        := palette["THEME_ACCENT"]
        AppState.THEME_ACCENT_DARK   := palette["THEME_ACCENT_DARK"]
        AppState.THEME_ACCENT_GLOW   := palette["THEME_ACCENT_GLOW"]

        AppState.THEME_SUCCESS       := palette["THEME_SUCCESS"]
        AppState.THEME_WARNING       := palette["THEME_WARNING"]
        AppState.THEME_DANGER        := palette["THEME_DANGER"]

        AppState.THEME_ON_ACCENT     := palette["THEME_ON_ACCENT"]

        AppState.ThemeMode := mode
        this.Current := mode
    }

    ; Apply the persisted theme at startup (after ConfigManager.Load).
    static Init() {
        this.Apply(AppState.ThemeMode)
    }

    static Label(mode) {
        return this.Normalize(mode) == this.Light
            ? Lang("MENU_THEME_LIGHT", "Light")
            : Lang("MENU_THEME_DARK", "Dark")
    }

    ; Switch theme at runtime: persist, drop cached GDI state, and close
    ; surfaces that would otherwise keep the previous palette.
    static Set(mode) {
        mode := this.Normalize(mode)

        if mode == this.Current {
            ShowToolTip(Lang("MSG_THEME_ALREADY", "Theme already set to {1}.", this.Label(mode)), 1600)
            return
        }

        this.Apply(mode)

        try ConfigManager.Save()

        ; Brushes, pens and owner-draw caches were built from the old palette.
        ThemeHelper.RefreshThemeResources()

        ; Transient menus are rebuilt on every open, so closing them is enough.
        try CustomMenu.Hide()

        ; Windows that cache their GUI object are destroyed (same approach as
        ; switching language); everything else picks up the new palette the
        ; next time it is opened.
        if IsObject(AppState.FullHistoryGui) {
            try AppState.FullHistoryGui.Destroy()
            AppState.FullHistoryGui := ""
        }

        ; A visible OSD was painted with the previous palette.
        if IsObject(OSD.currentOSD)
            try OSD.DestroyOSD(OSD.currentHwnd)

        ShowToolTip(
            Lang(mode == this.Light ? "MSG_THEME_LIGHT_SET" : "MSG_THEME_DARK_SET",
                mode == this.Light ? "Light theme enabled." : "Dark theme enabled.")
            . " " . Lang("MSG_THEME_REOPEN", "Reopen open windows to apply the change."),
            2600
        )
    }
}
