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

        accentColor := Theme.Primary
        icon := "💡"

        switch mytype {
            case "success": accentColor := Theme.Success, icon := "✅"
            case "warning": accentColor := Theme.Warning, icon := "⚠️"
            case "error":   accentColor := Theme.Error,  icon := "❌"
            default:        accentColor := Theme.Primary,  icon := "💡"
        }

        myOSD := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Border")
        myOSD.BackColor := Theme.Surface

        ; Left semantic status indicator bar
        myOSD.Add("Text", "x0 y3 w4 h59 Background" accentColor)

        myOSD.SetFont("s16", "Segoe UI Emoji")
        myOSD.Add("Text", "x16 y14 Background" Theme.Surface, icon)

        myOSD.SetFont("s11 Bold c" Theme.Text, Theme.Font)
        myOSD.Add("Text", "x48 y15 Background" Theme.Surface, text)

        myOSD.SetFont("s8 c" Theme.TextMuted, Theme.Font)
        myOSD.Add("Text", "x48 y39 Background" Theme.Surface, "CapsLock-  ·  " FormatTime(, "HH:mm:ss"))

        myOSD.Show("Hide")
        myOSD.GetPos(, , &ow, &oh)
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

; A minimal top-edge timer for the sequential CapsLock + Shift layer. The blue
; segment retracts from right to left as the remaining activation time expires.
class ShiftLayerToast {
    static DefaultDuration := 2000
    static UpdateInterval := 16
    static Width := 220
    static Height := 4

    static Gui := ""
    static Fill := ""
    static Timer := ""
    static StartedAt := 0
    static Duration := 0

    static Show(duration := 2000, targetHwnd := 0) {
        this.Duration := Max(1, Integer(duration))
        this.StartedAt := A_TickCount

        if !this._EnsureGui() {
            this.Hide()
            return false
        }

        this._GetPlacement(targetHwnd, &x, &y)
        try {
            this.Fill.Move(0, 0, this.Width, this.Height)
            this.Gui.Show(
                "x" x " y" y " w" this.Width " h" this.Height " NoActivate"
            )
        } catch {
            this.Hide()
            return false
        }

        if !IsObject(this.Timer) {
            this.Timer := ObjBindMethod(this, "_Tick")
            try SetTimer(this.Timer, this.UpdateInterval)
            catch {
                this.Hide()
                return false
            }
        }

        this._Tick()
        return true
    }

    static Hide() {
        if IsObject(this.Timer) {
            try SetTimer(this.Timer, 0)
            this.Timer := ""
        }

        if IsObject(this.Gui)
            try this.Gui.Destroy()

        this.Gui := ""
        this.Fill := ""
        this.StartedAt := 0
        this.Duration := 0
    }

    static _EnsureGui() {
        if IsObject(this.Gui) && IsObject(this.Fill) {
            hwnd := 0
            try hwnd := this.Gui.Hwnd
            if hwnd && WindowHandleAlive(hwnd)
                return true
        }

        toastGui := ""
        try {
            toastGui := Gui(
                "-DPIScale +AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000"
            )
            toastGui.BackColor := Theme.Background
            toastGui.MarginX := 0
            toastGui.MarginY := 0
            toastGui.Add(
                "Text",
                "x0 y0 w" this.Width " h" this.Height " Background" Theme.Outline
            )
            fill := toastGui.Add(
                "Text",
                "x0 y0 w" this.Width " h" this.Height " Background" Theme.Primary
            )

            this.Gui := toastGui
            this.Fill := fill
            return true
        } catch {
            try toastGui.Destroy()
            this.Gui := ""
            this.Fill := ""
            return false
        }
    }

    static _GetPlacement(targetHwnd, &x, &y) {
        left := 0
        top := 0
        right := A_ScreenWidth
        bottom := A_ScreenHeight

        if targetHwnd && WindowHandleAlive(targetHwnd) {
            try {
                monitor := DllCall(
                    "user32\MonitorFromWindow",
                    "Ptr", targetHwnd,
                    "UInt", 2, ; MONITOR_DEFAULTTONEAREST
                    "Ptr"
                )
                info := Buffer(40, 0)
                NumPut("UInt", info.Size, info)

                if monitor && DllCall(
                    "user32\GetMonitorInfoW",
                    "Ptr", monitor,
                    "Ptr", info,
                    "Int"
                ) {
                    left := NumGet(info, 4, "Int")
                    top := NumGet(info, 8, "Int")
                    right := NumGet(info, 12, "Int")
                    bottom := NumGet(info, 16, "Int")
                }
            } catch {
                left := 0
                top := 0
                right := A_ScreenWidth
                bottom := A_ScreenHeight
            }
        }

        x := left + Max(0, (right - left - this.Width) // 2)
        y := top
    }

    static _Tick(*) {
        if !IsObject(this.Gui) || !IsObject(this.Fill) {
            this.Hide()
            return
        }

        remaining := this.Duration - (A_TickCount - this.StartedAt)
        if remaining <= 0 {
            this.Hide()
            return
        }

        remainingWidth := Max(1, Round(this.Width * remaining / this.Duration))
        try this.Fill.Move(0, 0, remainingWidth, this.Height)
        catch
            this.Hide()
    }
}
