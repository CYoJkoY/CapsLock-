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

        myOSD.Add("Text", "x0 y0 w4 h60 Background" accentColor)

        myOSD.SetFont("s16", "Segoe UI Emoji")
        myOSD.Add("Text", "x16 y12 Background" AppState.THEME_SURFACE, icon)

        myOSD.SetFont("s11 c" AppState.THEME_FG, AppState.THEME_FONT)
        myOSD.Add("Text", "x48 y16 Background" AppState.THEME_SURFACE, text)

        myOSD.SetFont("s8 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        myOSD.Add("Text", "x48 y38 Background" AppState.THEME_SURFACE, FormatTime(, "HH:mm:ss"))

        myOSD.Show("Hide")
        myOSD.GetPos(, , &ow, &oh)
        savedHwnd := myOSD.Hwnd

        try {
            topMargin := 16
            posX := (A_ScreenWidth - ow) // 2
            posY := topMargin

            ThemeHelper.ApplyImmersiveDarkMode(savedHwnd)
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

    static ShowTopMostOSD(targetHwnd, isOnTop) {
        text := isOnTop ? "📌 " Lang("UI_ALWAYS_TOP") : "📌 " Lang("UI_UNPINNED")
        mytype := isOnTop ? "success" : "info"
        this.ShowNotification(text, 1500, mytype)
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
