#Requires AutoHotkey v2.0

global _DIS_OffHWND  := 20 + A_PtrSize - 4
global _DIS_OffHDC   := _DIS_OffHWND + A_PtrSize
global _DIS_OffRECT  := _DIS_OffHDC  + A_PtrSize

global _ODS_SELECTED    := 0x0001
global _ODS_DISABLED    := 0x0004
global _ODS_FOCUS       := 0x0010
global _ODS_HOTLIGHT    := 0x0040

class ThemeHelper {
    static _btnData    := Map()
    static _brushCache := Map()
    static _dcBrush    := 0
    static _fgColorRef := 0
    static _bgBrushRef := 0
    static _hooked     := false

    ; Cached GDI pen objects to avoid repeated CreatePen/DeleteObject calls
    static _borderPen    := 0
    static _focusPen     := 0
    static _borderPenRef := 0
    static _focusPenRef  := 0

    static StyleGui(myGui, variant := "default") {
        myGui.BackColor := AppState.THEME_BG
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        myGui.MarginX := 16
        myGui.MarginY := 16
    }

    static StyleButton(ctrl, bgColor := "") {
        if (bgColor = "")
            bgColor := this.ButtonColor("secondary")

        hwnd := ctrl.Hwnd

        try DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "ptr", 0, "ptr", 0)

        style := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -16, "ptr")
        DllCall("SetWindowLongPtr", "ptr", hwnd, "int", -16, "ptr", style | 0x0000000B)

        cref := this.RgbToColorRef(bgColor)
        if !this._brushCache.Has(cref)
            this._brushCache[cref] := DllCall("gdi32\CreateSolidBrush", "uint", cref, "ptr")
        if !this._fgColorRef
            this._fgColorRef := this.RgbToColorRef(AppState.THEME_FG)
        if !this._bgBrushRef
            this._bgBrushRef := DllCall("gdi32\CreateSolidBrush",
                "uint", this.RgbToColorRef(AppState.THEME_BG), "ptr")

        this._btnData[hwnd] := { cref: cref, text: ctrl.Text }

        if !this._hooked {
            OnMessage(0x002B, _ThemeHelper_DrawItem)
            OnMessage(0x0133, _ThemeHelper_CtlColorStatic)
            this._hooked := true
        }

        ctrl.Redraw()
    }

    static SetButtonText(ctrl, text) {
        hwnd := ctrl.Hwnd
        if this._btnData.Has(hwnd)
            this._btnData[hwnd].text := text
        ctrl.Text := text
        ctrl.Redraw()
    }

    static ButtonColor(style := "secondary") {
        switch style {
            case "primary":  return AppState.THEME_ACCENT_DARK
            case "danger":   return AppState.THEME_DANGER
            default:         return AppState.THEME_CONTROL_BG
        }
    }

    static RgbToColorRef(colorStr) {
        rgb := Integer(colorStr)
        return ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
    }

    static ShadeColor(cref, state) {
        r := cref & 0xFF
        g := (cref >> 8) & 0xFF
        b := (cref >> 16) & 0xFF
        if (state & _ODS_SELECTED) {
            r := Integer(r * 0.7)
            g := Integer(g * 0.7)
            b := Integer(b * 0.7)
        } else if (state & _ODS_HOTLIGHT) {
            r := Integer(Min(r * 1.15, 255))
            g := Integer(Min(g * 1.15, 255))
            b := Integer(Min(b * 1.15, 255))
        }
        return ((b & 0xFF) << 16) | ((g & 0xFF) << 8) | (r & 0xFF)
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

    static AddButton(myGui, options, label, style := "secondary") {
        btn := myGui.Add("Button", options " " this.GetButtonOptions(style), label)
        this.StyleButton(btn, this.ButtonColor(style))
        return btn
    }

    static GetButtonOptions(style := "secondary", extra := "") {
        return "Background" this.ButtonColor(style)
                . " c" AppState.THEME_FG
                . (extra ? " " extra : "")
    }

    static GetButtonPrimary(extra := "")   => this.GetButtonOptions("primary", extra)
    static GetButtonSecondary(extra := "") => this.GetButtonOptions("secondary", extra)
    static GetButtonDanger(extra := "")    => this.GetButtonOptions("danger", extra)

    static GetEditOptions(extra := "") {
        return "Background" AppState.THEME_CONTROL_BG
                . " c" AppState.THEME_FG . " Border"
                . (extra ? " " extra : "")
    }

    static GetLVOptions(extra := "") {
        return "Background" AppState.THEME_CONTROL_BG
                . " c" AppState.THEME_FG . " Grid"
                . (extra ? " " extra : "")
    }

    static GetCheckBoxOptions(extra := "") {
        return "c" AppState.THEME_FG . (extra ? " " extra : "")
    }

    static AddSeparator(myGui, width := 600, posY := "") {
        opt := "w" width " h2 Background" AppState.THEME_BORDER
        if (posY != "")
            opt .= " y" posY
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
        if (color = "") color := AppState.THEME_SUCCESS
        return myGui.Add("Text", "w10 h10 Background" color " Border")
    }

    static AddIconLabel(myGui, icon, text, color := "") {
        if (color = "") color := AppState.THEME_FG_DIM
        myGui.SetFont("s10 c" color, "Segoe UI Emoji")
        ctrl := myGui.Add("Text", , icon "  " text)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        return ctrl
    }

    static AddCard(myGui, title := "", width := 600, height := 100) {
        opt := "w" width " h" height
                . " Background" AppState.THEME_SURFACE
                . " c" AppState.THEME_FG_DIM
        if (title != "") opt .= " " title
        return myGui.Add("GroupBox", opt)
    }

    ; Release cached GDI resources (call on theme change or exit)
    static ReleaseResources() {
        if this._borderPen {
            DllCall("gdi32\DeleteObject", "ptr", this._borderPen)
            this._borderPen := 0
            this._borderPenRef := 0
        }
        if this._focusPen {
            DllCall("gdi32\DeleteObject", "ptr", this._focusPen)
            this._focusPen := 0
            this._focusPenRef := 0
        }
        for cref, brush in this._brushCache {
            DllCall("gdi32\DeleteObject", "ptr", brush)
        }
        this._brushCache := Map()
    }
}

_ThemeHelper_DrawItem(wParam, lParam, msg, hwnd) {
    if (NumGet(lParam + 0, "UInt") != 4)
        return

    itemState := NumGet(lParam + 16, "UInt")
    hwndItem  := NumGet(lParam + _DIS_OffHWND, "Ptr")
    hdc       := NumGet(lParam + _DIS_OffHDC, "Ptr")

    if !ThemeHelper._btnData.Has(hwndItem)
        return

    data := ThemeHelper._btnData[hwndItem]

    rcPtr   := lParam + _DIS_OffRECT
    rcLeft  := NumGet(rcPtr + 0,  "Int")
    rcTop   := NumGet(rcPtr + 4,  "Int")
    rcRight := NumGet(rcPtr + 8,  "Int")
    rcBot   := NumGet(rcPtr + 12, "Int")

    fillColor := ThemeHelper.ShadeColor(data.cref, itemState)

    if !ThemeHelper._dcBrush
        ThemeHelper._dcBrush := DllCall("GetStockObject", "Int", 18, "Ptr")

    DllCall("SetDCBrushColor", "Ptr", hdc, "UInt", fillColor)
    DllCall("FillRect", "Ptr", hdc, "Ptr", rcPtr, "Ptr", ThemeHelper._dcBrush)

    ; Use cached GDI pens to avoid repeated CreatePen/DeleteObject calls.
    ; Pens are created once per border/focus color and reused across all DrawItem calls.
    if (itemState & _ODS_FOCUS) {
        focusRef := ThemeHelper.RgbToColorRef(AppState.THEME_ACCENT)
        if !ThemeHelper._focusPen || ThemeHelper._focusPenRef != focusRef {
            if ThemeHelper._focusPen
                DllCall("gdi32\DeleteObject", "ptr", ThemeHelper._focusPen)
            ThemeHelper._focusPen := DllCall("gdi32\CreatePen", "int", 0, "int", 1, "uint", focusRef, "ptr")
            ThemeHelper._focusPenRef := focusRef
        }
        pen := ThemeHelper._focusPen
    } else {
        borderRef := ThemeHelper.RgbToColorRef(AppState.THEME_BORDER)
        if !ThemeHelper._borderPen || ThemeHelper._borderPenRef != borderRef {
            if ThemeHelper._borderPen
                DllCall("gdi32\DeleteObject", "ptr", ThemeHelper._borderPen)
            ThemeHelper._borderPen := DllCall("gdi32\CreatePen", "int", 0, "int", 1, "uint", borderRef, "ptr")
            ThemeHelper._borderPenRef := borderRef
        }
        pen := ThemeHelper._borderPen
    }

    oldPen := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", pen, "ptr")
    DllCall("gdi32\Rectangle", "ptr", hdc, "int", rcLeft, "int", rcTop, "int", rcRight, "int", rcBot)
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen, "ptr")
    ; Pen is NOT deleted - it's cached for reuse

    txtColor := (itemState & _ODS_DISABLED)
        ? ThemeHelper.RgbToColorRef(AppState.THEME_FG_MUTED)
        : ThemeHelper._fgColorRef

    DllCall("gdi32\SetTextColor", "ptr", hdc, "uint", txtColor)
    DllCall("gdi32\SetBkMode", "ptr", hdc, "int", 1)

    hFont   := DllCall("gdi32\GetStockObject", "int", 17, "ptr")
    oldFont := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", hFont, "ptr")

    DllCall("user32\DrawTextW", "ptr", hdc, "str", data.text,
            "int", -1, "ptr", rcPtr, "uint", 0x25)

    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldFont, "ptr")

    return 1
}

_ThemeHelper_CtlColorStatic(wParam, lParam, msg, hwnd) {
    DllCall("gdi32\SetTextColor", "ptr", wParam,
            "uint", ThemeHelper.RgbToColorRef(AppState.THEME_FG))
    bgCref := ThemeHelper.RgbToColorRef(AppState.THEME_BG)
    DllCall("gdi32\SetBkColor", "ptr", wParam, "uint", bgCref)

    if !ThemeHelper._bgBrushRef
        ThemeHelper._bgBrushRef := DllCall("gdi32\CreateSolidBrush", "uint", bgCref, "ptr")
    return ThemeHelper._bgBrushRef
}
