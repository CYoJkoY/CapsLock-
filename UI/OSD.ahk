#Requires AutoHotkey v2.0

class OSD {
    static currentOSD := ""
    static currentHwnd := 0
    static fadeTimer := ""
    static autoDestroyTimer := ""

    ; Show a modern toast notification
    static ShowNotification(text, duration := 1500) {
        ; Cancel any pending timers
        if this.fadeTimer != "" {
            SetTimer(this.fadeTimer, 0)
            this.fadeTimer := ""
        }
        if this.autoDestroyTimer != "" {
            SetTimer(this.autoDestroyTimer, 0)
            this.autoDestroyTimer := ""
        }

        ; Destroy previous OSD
        if IsObject(this.currentOSD) {
            try this.currentOSD.Destroy()
            this.currentOSD := ""
            this.currentHwnd := 0
        }

        ; Create Modern GUI
        myOSD := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Border")
        myOSD.BackColor := AppState.THEME_BG
        myOSD.SetFont("s11 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; Use a slightly larger text with padding
        txtCtrl := myOSD.Add("Text", "x20 y10 w200 Center", text)

        ; Auto-size the GUI to fit text
        myOSD.Show("Hide")
        myOSD.GetPos(,, &ow, &oh)

        ; Save hwnd immediately as an integer (survives Destroy)
        savedHwnd := myOSD.Hwnd

        try {
            ; Get active window or screen center
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
                } catch {
                    ; Fallback to screen center
                }
            }

            myOSD.Show("x" posX " y" posY " NoActivate")

            ; Apply dark mode to the OSD window border
            ThemeHelper.ApplyImmersiveDarkMode(savedHwnd)

            ; Ensure it starts invisible for fade-in
            WinSetTransparent(0, myOSD)

            this.currentOSD := myOSD
            this.currentHwnd := savedHwnd

            ; Start fade-in
            this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "in")
            SetTimer(this.fadeTimer, -10)

            ; Auto destroy after duration (safety net)
            ; Use savedHwnd (integer) instead of myOSD.Hwnd to avoid "Gui has no window"
            this.autoDestroyTimer := ObjBindMethod(this, "AutoDestroyCheck", savedHwnd)
            SetTimer(this.autoDestroyTimer, -duration)

        } catch as e {
            try myOSD.Destroy()
            this.currentOSD := ""
            this.currentHwnd := 0
        }
    }

    ; Safety check: only destroy if this is still the current OSD
    static AutoDestroyCheck(savedHwnd) {
        this.autoDestroyTimer := ""
        if this.currentHwnd == savedHwnd && WinExist("ahk_id " savedHwnd) {
            this.StopFade()
        }
    }

    ; Keep original TopMost OSD for specific toggle feature but styled
    static ShowTopMostOSD(targetHwnd, isOnTop) {
        text := isOnTop ? Lang("UI_ALWAYS_TOP") : Lang("UI_UNPINNED")
        this.ShowNotification(text, 1500)
    }

    ; Enhanced Fade Animation (uses savedHwnd integer instead of GUI object)
    static Fade(savedHwnd, state) {
        ; Check if window still exists
        if !WinExist("ahk_id " savedHwnd) {
            this.StopFade()
            return
        }

        ; If this is no longer the current OSD, stop
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

        static step := 15
        static maxAlpha := 255
        static holdTime := 1200

        if state == "in" {
            if trans < maxAlpha {
                newVal := Min(trans + step, maxAlpha)
                WinSetTransparent(newVal, "ahk_id " savedHwnd)
                if newVal < maxAlpha {
                    this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "in")
                    SetTimer(this.fadeTimer, -15)
                } else {
                    this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "hold")
                    SetTimer(this.fadeTimer, -holdTime)
                }
            } else {
                this.fadeTimer := ObjBindMethod(this, "Fade", savedHwnd, "hold")
                SetTimer(this.fadeTimer, -holdTime)
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
                    SetTimer(this.fadeTimer, -15)
                } else {
                    this.DestroyOSD(savedHwnd)
                }
            } else {
                this.DestroyOSD(savedHwnd)
            }
        }
    }

    ; Safely destroy the OSD window
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
