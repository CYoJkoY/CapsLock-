#Requires AutoHotkey v2.0

; Wabi Press color system. Paper, ink, and a few mineral pigments carry the
; hierarchy; cinnabar is reserved for primary actions, selection, and seals.
; Legacy semantic names stay in place so every consumer keeps one vocabulary.
class Theme {
    static Dark := "dark"
    static Light := "light"
    static Default := "dark"
    static Modes := ["dark", "light"]
    static Current := "dark"

    ; Semantic tokens consumed by all UI modules. Component code speaks in
    ; roles (Surface, PrimaryContainer, TextSecondary), never palette values.
    static Background := "0x131416"
    static Surface := "0x1B1C20"
    static Overlay := "0x25272D"
    static PrimaryContainer := "0x352A27"
    static Control := "0x25272D"
    static ControlHover := "0x2D3036"
    static Outline := "0x3A3733"
    static CardLine := "0x3A3733"
    static Text := "0xEDEAE2"
    static TextSecondary := "0xA39F95"
    static TextMuted := "0xAAA397"
    static Primary := "0xE18C7C"
    static OnPrimaryContainer := "0xEDEAE2"
    static OnPrimary := "0x1B1311"
    static Ink := "0xEDEAE2"
    static Cinnabar := "0xE18C7C"
    static Moss := "0x9AB49E"
    static Focus := "0x9EBBCB"
    static Ochre := "0xD5B576"
    static Clay := "0xCEA38E"
    static Success := "0x9AB49E"
    static Warning := "0xD5B576"
    static Error := "0xE18C7C"

    static Font := "Segoe UI"
    static FontSerif := "Source Han Serif SC"
    static FontMono := "Cascadia Code"
    static Radius := 2
    ; Spacing follows a 4px paper grid: margins, gutters, and rail offsets all
    ; derive from these, so dense windows and roomy pages keep one rhythm.
    static SpaceXS := 4
    static SpaceS := 8
    static SpaceM := 12
    static SpaceL := 16
    static SpaceXL := 24
    static Hairline := 1
    static RailWidth := 2

    static Palettes := Map(
        "dark", Map(
            "Background", "0x131416",
            "Surface", "0x1B1C20",
            "Overlay", "0x25272D",
            "PrimaryContainer", "0x352A27",
            "Control", "0x25272D",
            "ControlHover", "0x2D3036",
            "Outline", "0x3A3733",
            "CardLine", "0x3A3733",
            "Text", "0xEDEAE2",
            "TextSecondary", "0xA39F95",
            "TextMuted", "0xAAA397",
            "Primary", "0xE18C7C",
            "OnPrimaryContainer", "0xEDEAE2",
            "OnPrimary", "0x1B1311",
            "Ink", "0xEDEAE2",
            "Cinnabar", "0xE18C7C",
            "Moss", "0x9AB49E",
            "Focus", "0x9EBBCB",
            "Ochre", "0xD5B576",
            "Clay", "0xCEA38E",
            "Success", "0x9AB49E",
            "Warning", "0xD5B576",
            "Error", "0xE18C7C"
        ),
        "light", Map(
            "Background", "0xF5F3EC",
            "Surface", "0xFAF9F5",
            "Overlay", "0xECE8DC",
            "PrimaryContainer", "0xEEE2DA",
            "Control", "0xECE8DC",
            "ControlHover", "0xE4DED0",
            "Outline", "0xD8D2C4",
            "CardLine", "0xDDD6C7",
            "Text", "0x1C1A17",
            "TextSecondary", "0x524C44",
            "TextMuted", "0x6E675D",
            "Primary", "0xA6382A",
            "OnPrimaryContainer", "0x1C1A17",
            "OnPrimary", "0xFBF9F2",
            "Ink", "0x1C1A17",
            "Cinnabar", "0xA6382A",
            "Moss", "0x3B5848",
            "Focus", "0x405F73",
            "Ochre", "0x795B28",
            "Clay", "0x855747",
            "Success", "0x3B5848",
            "Warning", "0x795B28",
            "Error", "0xA6382A"
        )
    )

    static Normalize(mode) {
        mode := StrLower(Trim(String(mode)))
        for candidate in this.Modes {
            if candidate == mode
                return mode
        }
        return this.Default
    }

    static IsDark() => this.Current == this.Dark

    ; Apply the selected palette once, then let all UI modules read the same
    ; semantic roles. Configuration stores only the selected mode.
    static Apply(mode := "") {
        if (mode == "")
            mode := this.Current

        mode := this.Normalize(mode)
        palette := this.Palettes[mode]

        this.Background        := palette["Background"]
        this.Surface           := palette["Surface"]
        this.Overlay           := palette["Overlay"]
        this.PrimaryContainer  := palette["PrimaryContainer"]
        this.Control            := palette["Control"]
        this.ControlHover       := palette["ControlHover"]
        this.Outline            := palette["Outline"]
        this.CardLine           := palette["CardLine"]
        this.Text               := palette["Text"]
        this.TextSecondary      := palette["TextSecondary"]
        this.TextMuted          := palette["TextMuted"]
        this.Primary            := palette["Primary"]
        this.OnPrimaryContainer := palette["OnPrimaryContainer"]
        this.OnPrimary          := palette["OnPrimary"]
        this.Ink                := palette["Ink"]
        this.Cinnabar           := palette["Cinnabar"]
        this.Moss               := palette["Moss"]
        this.Focus              := palette["Focus"]
        this.Ochre              := palette["Ochre"]
        this.Clay               := palette["Clay"]
        this.Success            := palette["Success"]
        this.Warning            := palette["Warning"]
        this.Error              := palette["Error"]

        AppState.ThemeMode := mode
        this.Current := mode
    }

    ; Apply the persisted mode after ConfigManager.Load().
    static Init() => this.Apply(AppState.ThemeMode)

    static Label(mode) {
        return this.Normalize(mode) == this.Light
            ? Lang("MENU_THEME_LIGHT", "Light")
            : Lang("MENU_THEME_DARK", "Dark")
    }

    static Toggle() {
        this.Set(this.IsDark() ? this.Light : this.Dark)
    }

    ; Update persisted state and rebuild only surfaces that cache GDI colors.
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

        ShowToolTip(
            Lang(mode == this.Light ? "MSG_THEME_LIGHT_SET" : "MSG_THEME_DARK_SET",
                mode == this.Light ? "Light theme enabled." : "Dark theme enabled.")
            . Lang("MSG_THEME_REOPEN", "Reopen open windows to apply the change."),
            2600
        )
    }
}
