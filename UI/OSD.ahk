#Requires AutoHotkey v2.0

class OSD {
    static currentOSD := ""
    static currentHwnd := 0
    static fadeTimer := ""
    static autoDestroyTimer := ""

    static ShowNotification(text, duration := 1500, mytype := "info") {
        if this.fadeTimer != "" {
            SetTimer(this.fadeTimer, 0)
            this.fadeTimer := ""
        }
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
        txtCtrl := myOSD.Add("Text", "x48 y16 Background" AppState.THEME_SURFACE, text)

        myOSD.SetFont("s8 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        myOSD.Add("Text", "x48 y38 Background" AppState.THEME_SURFACE,
            FormatTime(, "HH:mm:ss"))

        myOSD.Show("Hide")
        myOSD.GetPos(, , &ow, &oh)
        savedHwnd := myOSD.Hwnd

        try {
            activeHwnd := WinExist("A")
            posX := A_ScreenWidth / 2 - ow / 2
            posY := A_ScreenHeight / 2 - oh / 2 - 100

            if activeHwnd {
                try {
                    WinGetPos(&wx, &wy, &ww, &wh, activeHwnd)
                    posX := wx + (ww / 2) - (ow / 2)
                    posY := wy + (wh / 4)
                    if (posX + ow > A_ScreenWidth)
                        posX := A_ScreenWidth - ow - 10
                    if (posX < 0)
                        posX := 10
                    if (posY < 0)
                        posY := 10
                }
            }

            myOSD.Show("x" posX " y" posY " NoActivate")
            ThemeHelper.ApplyImmersiveDarkMode(savedHwnd)
            WinSetTransparent(0, myOSD)

            this.currentOSD := myOSD
            this.currentHwnd := savedHwnd

            this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "in")
            SetTimer(this.fadeTimer, -10)

            this.autoDestroyTimer := ObjBindMethod(this, "AutoDestroyCheck", savedHwnd)
            SetTimer(this.autoDestroyTimer, -duration)

        } catch {
            try myOSD.Destroy()
            this.currentOSD := ""
            this.currentHwnd := 0
        }
    }

    static ShowTopMostOSD(targetHwnd, isOnTop) {
        text := isOnTop ? Lang("UI_ALWAYS_TOP") : Lang("UI_UNPINNED")
        mytype := isOnTop ? "success" : "info"
        this.ShowNotification(text, 1500, mytype)
    }

    static AutoDestroyCheck(savedHwnd) {
        this.autoDestroyTimer := ""
        if this.currentHwnd == savedHwnd && WinExist("ahk_id " savedHwnd) {
            this.StopFade()
        }
    }

    static Fade(savedHwnd, state) {
        if !WinExist("ahk_id " savedHwnd) {
            this.StopFade()
            return
        }
        if this.currentHwnd != savedHwnd {
            this.StopFade()
            return
        }
        try {
            trans := WinGetTransparent("ahk_id " savedHwnd)
        } catch {
            this.StopFade()
            return
        }

        static step := 18
        static maxAlpha := 245

        if state == "in" {
            if trans < maxAlpha {
                newVal := Min(trans + step, maxAlpha)
                WinSetTransparent(newVal, "ahk_id " savedHwnd)
                if newVal < maxAlpha {
                    this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "in")
                    SetTimer(this.fadeTimer, -12)
                } else {
                    this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "hold")
                    SetTimer(this.fadeTimer, -1200)
                }
            } else {
                this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "hold")
                SetTimer(this.fadeTimer, -1200)
            }
        } else if state == "hold" {
            this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "out")
            SetTimer(this.fadeTimer, -20)
        } else if state == "out" {
            if trans > 0 {
                newVal := Max(trans - step, 0)
                WinSetTransparent(newVal, "ahk_id " savedHwnd)
                if newVal > 0 {
                    this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "out")
                    SetTimer(this.fadeTimer, -12)
                } else {
                    this.DestroyOSD(savedHwnd)
                }
            } else {
                this.DestroyOSD(savedHwnd)
            }
        }
    }

    static DestroyOSD(savedHwnd) {
        if this.fadeTimer != "" {
            SetTimer(this.fadeTimer, 0)
            this.fadeTimer := ""
        }
        if this.autoDestroyTimer != "" {
            SetTimer(this.autoDestroyTimer, 0)
            this.autoDestroyTimer := ""
        }
        if this.currentHwnd == savedHwnd {
            if IsObject(this.currentOSD) {
                try this.currentOSD.Destroy()
            }
            this.currentOSD := ""
            this.currentHwnd := 0
        }
    }

    static StopFade() {
        if this.fadeTimer != "" {
            SetTimer(this.fadeTimer, 0)
            this.fadeTimer := ""
        }
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
