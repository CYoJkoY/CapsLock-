#Requires AutoHotkey v2.0

class OSD {
    static currentOSD := ""
    static currentHwnd := 0
    static autoDestroyTimer := ""

    static ShowNotification(text, duration := 1500, mytype := "info") {
        if this.autoDestroyTimer != "" {
            SetTimer(this.autoDestroyTimer, 0)
            this.autoDestroyTimer := ""
        }

        if IsObject(this.currentOSD) {
            try this.currentOSD.Destroy()
            this.currentOSD := ""
            this.currentHwnd := 0
        }

        accentColor := AppState.THEME_ACCENT
        icon := "💡"

        switch mytype {
            case "success": accentColor := AppState.THEME_SUCCESS, icon := "✅"
            case "warning": accentColor := AppState.THEME_WARNING, icon := "⚠️"
            case "error":   accentColor := AppState.THEME_DANGER,  icon := "❌"
            default:        accentColor := AppState.THEME_ACCENT,  icon := "💡"
        }

        myOSD := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Border")
        myOSD.BackColor := AppState.THEME_SURFACE

        ; Left semantic status indicator bar
        myOSD.Add("Text", "x0 y3 w4 h59 Background" accentColor)

        myOSD.SetFont("s16", "Segoe UI Emoji")
        myOSD.Add("Text", "x16 y14 Background" AppState.THEME_SURFACE, icon)

        myOSD.SetFont("s11 Bold c" AppState.THEME_FG, AppState.THEME_FONT)
        myOSD.Add("Text", "x48 y15 Background" AppState.THEME_SURFACE, text)

        myOSD.SetFont("s8 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        myOSD.Add("Text", "x48 y39 Background" AppState.THEME_SURFACE, "CapsLock-  ·  " FormatTime(, "HH:mm:ss"))

        myOSD.Show("Hide")
        myOSD.GetPos(, , &ow, &oh)
        ThemeHelper.AddGoogleAccentBar(myOSD, 0, 0, ow, 3)
        savedHwnd := myOSD.Hwnd

        try {
            topMargin := 16
            posX := (A_ScreenWidth - ow) // 2
            posY := topMargin

            ThemeHelper.ApplyWindowTheme(savedHwnd)
            myOSD.Show("x" posX " y" posY " NoActivate")

            this.currentOSD := myOSD
            this.currentHwnd := savedHwnd

            this.autoDestroyTimer := ObjBindMethod(this, "DestroyOSD", savedHwnd)
            SetTimer(this.autoDestroyTimer, -duration)
        } catch {
            try myOSD.Destroy()
            this.currentOSD := ""
            this.currentHwnd := 0
        }
    }

    ; Always-on-top confirmation.
    ;
    ; The toast is transient, so it names the window it acted on and uses two
    ; clearly different presentations for the two states (accent vs. muted,
    ; pinned vs. unpinned wording). The persistent part of the state lives in
    ; PinIndicator; this only has to be unambiguous while it is on screen.
    static ShowTopMostOSD(targetHwnd, isOnTop) {
        text := isOnTop
            ? "📌 " Lang("UI_ALWAYS_TOP") . "  ·  " . this._WindowLabel(targetHwnd)
            : "○ " Lang("UI_UNPINNED") . "  ·  " . this._WindowLabel(targetHwnd)
        mytype := isOnTop ? "success" : "info"
        this.ShowNotification(text, 1500, mytype)
    }

    ; Window title for OSD text, clipped so a long title cannot stretch the
    ; toast across the whole screen.
    static _WindowLabel(targetHwnd) {
        if !targetHwnd
            return ""

        title := ""
        try
            title := WinGetTitle("ahk_id " targetHwnd)
        catch
            title := ""

        if title == ""
            return ""

        if StrLen(title) > 38
            title := SubStr(title, 1, 37) "…"

        return title
    }

    static DestroyOSD(savedHwnd) {
        if this.currentHwnd != savedHwnd
            return

        if this.autoDestroyTimer != "" {
            SetTimer(this.autoDestroyTimer, 0)
            this.autoDestroyTimer := ""
        }

        if IsObject(this.currentOSD) {
            try this.currentOSD.Destroy()
        }

        this.currentOSD := ""
        this.currentHwnd := 0
    }
}
