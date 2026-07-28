#Requires AutoHotkey v2.0

class ThemeHelper {
    static _btnBrushes := Map()
    static _brushCache := Map()
    static _fgColorRef := 0
    static _ctlHooked := false

    static StyleGui(myGui, variant := "default") {
        myGui.BackColor := AppState.THEME_BG
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        myGui.MarginX := 16
        myGui.MarginY := 16
    }

    static RgbToColorRef(colorStr) {
        rgb := Integer(colorStr)
        return ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
    }

    static ButtonColor(style := "secondary") {
        switch style {
            case "primary": return AppState.THEME_ACCENT_DARK
            case "danger":  return AppState.THEME_DANGER
            default:        return AppState.THEME_CONTROL_BG
        }
    }

    static StyleButton(ctrl, bgColor := "") {
        if (bgColor = "")
            bgColor := this.ButtonColor("secondary")
        try DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "ptr", 0, "ptr", 0)
        if !this._brushCache.Has(bgColor)
            this._brushCache[bgColor] := DllCall("gdi32\CreateSolidBrush", "uint", this.RgbToColorRef(bgColor), "ptr")
        this._btnBrushes[ctrl.Hwnd] := { brush: this._brushCache[bgColor], cref: this.RgbToColorRef(bgColor) }
        if !this._fgColorRef
            this._fgColorRef := this.RgbToColorRef(AppState.THEME_FG)
        this._HookCtlColors()
        ctrl.Redraw()
    }

    static _HookCtlColors() {
        if this._ctlHooked
            return
        OnMessage(0x0135, ThemeHelper_OnCtlColorBtn)
        this._ctlHooked := true
    }

    static StyleListView(ctrl) {
        this.StyleScrollbar(ctrl)
        headerHwnd := SendMessage(0x101F, 0, 0, ctrl.Hwnd)
        if headerHwnd
            try DllCall("uxtheme\SetWindowTheme", "ptr", headerHwnd, "wstr", "DarkMode_ItemsView", "ptr", 0)
        ctrl.Redraw()
    }

    static StyleScrollbar(ctrl) {
        try DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "wstr", "DarkMode_Explorer", "ptr", 0)
    }

    static ApplyImmersiveDarkMode(hwnd) {
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "int*", 1, "int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 34, "int*", this.RgbToColorRef(AppState.THEME_BORDER),  "int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 35, "int*", this.RgbToColorRef(AppState.THEME_SURFACE), "int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 36, "int*", this.RgbToColorRef(AppState.THEME_FG),      "int", 4)
    }

    static GetEditOptions(extra := "") {
        return "Background" AppState.THEME_CONTROL_BG
            . " c" AppState.THEME_FG
            . " Border"
            . (extra ? " " extra : "")
    }

    static GetLVOptions(extra := "") {
        return "Background" AppState.THEME_CONTROL_BG
            . " c" AppState.THEME_FG
            . " Grid"
            . (extra ? " " extra : "")
    }

    static AddButton(myGui, options, label, style := "secondary") {
        btn := myGui.Add("Button", options " " this.GetButtonOptions(style), label)
        this.StyleButton(btn, this.ButtonColor(style))
        return btn
    }

    static GetButtonPrimary(extra := "") {
        return this.GetButtonOptions("primary", extra)
    }

    static GetButtonSecondary(extra := "") {
        return this.GetButtonOptions("secondary", extra)
    }

    static GetButtonDanger(extra := "") {
        return this.GetButtonOptions("danger", extra)
    }

    static GetButtonOptions(style := "secondary", extra := "") {
        return "Background" this.ButtonColor(style)
            . " c" AppState.THEME_FG
            . (extra ? " " extra : "")
    }

    static GetCheckBoxOptions(extra := "") {
        return "c" AppState.THEME_FG . (extra ? " " extra : "")
    }

    static AddSeparator(myGui, width := 600, y := "") {
        opt := "w" width " h2 Background" AppState.THEME_BORDER
        if (y != "")
            opt .= " y" y
        return myGui.Add("Text", opt)
    }

    static AddTitle(myGui, text, width := 600) {
        myGui.SetFont("s14 Bold c" AppState.THEME_ACCENT, AppState.THEME_FONT)
        ctrl := myGui.Add("Text", "w" width, text)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        return ctrl
    }

    static AddSubtitle(myGui, text, width := 600) {
        myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        ctrl := myGui.Add("Text", "w" width, text)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        return ctrl
    }

    static AddStatusDot(myGui, color := "") {
        if (color == "")
            color := AppState.THEME_SUCCESS
        return myGui.Add("Text", "w10 h10 Background" color " Border")
    }

    static AddIconLabel(myGui, icon, text, color := "") {
        if (color == "")
            color := AppState.THEME_FG_DIM
        myGui.SetFont("s10 c" color, "Segoe UI Emoji")
        ctrl := myGui.Add("Text", , icon "  " text)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        return ctrl
    }

    static AddCard(myGui, title := "", width := 600, height := 100) {
        opt := "w" width " h" height
            . " Background" AppState.THEME_SURFACE
            . " c" AppState.THEME_FG_DIM
        if (title != "")
            opt .= " " title
        return myGui.Add("GroupBox", opt)
    }
}

ThemeHelper_OnCtlColorBtn(wParam, lParam, msg, hwnd) {
    if !ThemeHelper._btnBrushes.Has(lParam)
        return
    entry := ThemeHelper._btnBrushes[lParam]
    DllCall("SetTextColor", "ptr", wParam, "uint", ThemeHelper._fgColorRef)
    DllCall("SetBkColor",   "ptr", wParam, "uint", entry.cref)
    return entry.brush
}
