#Requires AutoHotkey v2.0

; Material 3-inspired color system. Neutral surfaces establish hierarchy;
; blue is reserved for primary actions, selection, and keyboard focus.
class Theme {
    static Dark := "dark"
    static Light := "light"
    static Default := "dark"
    static Modes := ["dark", "light"]
    static Current := "dark"

    ; Semantic tokens consumed by all UI modules. Keep component code expressed
    ; in roles (Surface, PrimaryContainer, TextSecondary), not palette values.
    static Background := "0x202124"
    static Surface := "0x292A2D"
    static PrimaryContainer := "0x394B64"
    static Control := "0x303134"
    static ControlHover := "0x3C4043"
    static Outline := "0x3C4043"
    static Text := "0xE8EAED"
    static TextSecondary := "0x9AA0A6"
    static TextMuted := "0x92979B"
    static Primary := "0xA8C7FA"
    static OnPrimaryContainer := "0xD3E3FD"
    static OnPrimary := "0x202124"
    static Success := "0x81C995"
    static Warning := "0xFDD663"
    static Error := "0xF28B82"

    static Font := "Segoe UI"
    static FontMono := "Cascadia Code"
    static Radius := 12

    static Palettes := Map(
        "dark", Map(
            "Background", "0x202124",
            "Surface", "0x292A2D",
            "PrimaryContainer", "0x394B64",
            "Control", "0x303134",
            "ControlHover", "0x3C4043",
            "Outline", "0x3C4043",
            "Text", "0xE8EAED",
            "TextSecondary", "0x9AA0A6",
            "TextMuted", "0x92979B",
            "Primary", "0xA8C7FA",
            "OnPrimaryContainer", "0xD3E3FD",
            "OnPrimary", "0x202124",
            "Success", "0x81C995",
            "Warning", "0xFDD663",
            "Error", "0xF28B82"
        ),
        "light", Map(
            "Background", "0xF8F9FA",
            "Surface", "0xFFFFFF",
            "PrimaryContainer", "0xE8F0FE",
            "Control", "0xF1F3F4",
            "ControlHover", "0xE8EAED",
            "Outline", "0xDADCE0",
            "Text", "0x202124",
            "TextSecondary", "0x5F6368",
            "TextMuted", "0x6B7075",
            "Primary", "0x0B57D0",
            "OnPrimaryContainer", "0x174EA6",
            "OnPrimary", "0xFFFFFF",
            "Success", "0x188038",
            "Warning", "0xB06000",
            "Error", "0xB3261E"
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
        this.PrimaryContainer  := palette["PrimaryContainer"]
        this.Control            := palette["Control"]
        this.ControlHover       := palette["ControlHover"]
        this.Outline            := palette["Outline"]
        this.Text               := palette["Text"]
        this.TextSecondary      := palette["TextSecondary"]
        this.TextMuted          := palette["TextMuted"]
        this.Primary            := palette["Primary"]
        this.OnPrimaryContainer := palette["OnPrimaryContainer"]
        this.OnPrimary          := palette["OnPrimary"]
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
            . " " . Lang("MSG_THEME_REOPEN", "Reopen open windows to apply the change."),
            2600
        )
    }
}
