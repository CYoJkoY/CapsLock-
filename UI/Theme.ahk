#Requires AutoHotkey v2.0

; Wabi-Press / 侘寂刊本 visual contract.
; The application is intentionally rendered as a quiet editorial instrument:
; washi paper, pine-soot ink, cinnabar seals and moss accents. All controls
; consume these semantic roles; no view owns a private palette.
class Theme {
    static Dark := "dark"
    static Light := "light"
    static Default := "dark"
    static Modes := ["dark", "light"]
    static Current := "dark"

    ; Light spectrum: warm washi / ink / cinnabar / moss.
    static Background := "0xF5F3EC"
    static Surface := "0xFAF9F5"
    static PrimaryContainer := "0xECE8DC"
    static Control := "0xECE8DC"
    static ControlHover := "0xE2DED2"
    static Outline := "0xBDB6A9"
    static Text := "0x1C1A17"
    static TextSecondary := "0x524C44"
    static TextMuted := "0x878074"
    static Primary := "0xA6382A"
    static OnPrimaryContainer := "0x3B5848"
    static OnPrimary := "0xF5F3EC"
    static Success := "0x3B5848"
    static Warning := "0x9A5B28"
    static Error := "0xA6382A"

    static Font := "Segoe UI"
    static FontEditorial := "Source Han Serif SC"
    static FontMono := "Cascadia Mono"
    static Radius := 2

    static Palettes := Map(
        "light", Map(
            "Background", "0xF5F3EC", "Surface", "0xFAF9F5",
            "PrimaryContainer", "0xECE8DC", "Control", "0xECE8DC",
            "ControlHover", "0xE2DED2", "Outline", "0xBDB6A9",
            "Text", "0x1C1A17", "TextSecondary", "0x524C44", "TextMuted", "0x878074",
            "Primary", "0xA6382A", "OnPrimaryContainer", "0x3B5848", "OnPrimary", "0xF5F3EC",
            "Success", "0x3B5848", "Warning", "0x9A5B28", "Error", "0xA6382A"
        ),
        "dark", Map(
            "Background", "0x131416", "Surface", "0x1B1C20",
            "PrimaryContainer", "0x25272D", "Control", "0x25272D",
            "ControlHover", "0x303239", "Outline", "0x5A5955",
            "Text", "0xEDEAE2", "TextSecondary", "0xA39F95", "TextMuted", "0x68645C",
            "Primary", "0xC84A3B", "OnPrimaryContainer", "0x537B65", "OnPrimary", "0x131416",
            "Success", "0x537B65", "Warning", "0xC1814D", "Error", "0xC84A3B"
        )
    )

    static Normalize(mode) {
        mode := StrLower(Trim(String(mode)))
        for candidate in this.Modes
            if candidate == mode
                return mode
        return this.Default
    }
    static IsDark() => this.Current == this.Dark

    static Apply(mode := "") {
        mode := this.Normalize(mode == "" ? this.Current : mode)
        palette := this.Palettes[mode]
        this.Background        := palette["Background"]
        this.Surface           := palette["Surface"]
        this.PrimaryContainer  := palette["PrimaryContainer"]
        this.Control           := palette["Control"]
        this.ControlHover      := palette["ControlHover"]
        this.Outline           := palette["Outline"]
        this.Text              := palette["Text"]
        this.TextSecondary     := palette["TextSecondary"]
        this.TextMuted         := palette["TextMuted"]
        this.Primary           := palette["Primary"]
        this.OnPrimaryContainer := palette["OnPrimaryContainer"]
        this.OnPrimary          := palette["OnPrimary"]
        this.Success           := palette["Success"]
        this.Warning           := palette["Warning"]
        this.Error             := palette["Error"]
        AppState.ThemeMode := mode
        this.Current := mode
    }
    static Init() => this.Apply(AppState.ThemeMode)
    static Label(mode) => this.Normalize(mode) == this.Light ? Lang("MENU_THEME_LIGHT", "Light") : Lang("MENU_THEME_DARK", "Dark")
    static Toggle() => this.Set(this.IsDark() ? this.Light : this.Dark)

    static Set(mode) {
        mode := this.Normalize(mode)
        if mode == this.Current {
            ShowToolTip(Lang("MSG_THEME_ALREADY", "Theme already set to {1}.", this.Label(mode)), 1600)
            return
        }
        this.Apply(mode)
        try ConfigManager.Save()
        ThemeHelper.RefreshThemeResources()
        try CustomMenu.Hide()
        if IsObject(AppState.FullHistoryGui) {
            try AppState.FullHistoryGui.Destroy()
            AppState.FullHistoryGui := ""
        }
        if IsObject(OSD.currentOSD)
            try OSD.DestroyOSD(OSD.currentHwnd)
        try PinIndicator.RefreshTheme()
        if IsSet(SettingsGui) && SettingsGui.IsOpen()
            try SettingsGui.RefreshTheme()
        ShowToolTip(Lang(mode == this.Light ? "MSG_THEME_LIGHT_SET" : "MSG_THEME_DARK_SET", mode == this.Light ? "Light theme enabled." : "Dark theme enabled.") . " " . Lang("MSG_THEME_REOPEN", "Reopen open windows to apply the change."), 2600)
    }
}
