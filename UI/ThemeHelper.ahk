#Requires AutoHotkey v2.0

global _DIS_OffHWND  := 20 + A_PtrSize - 4
global _DIS_OffHDC   := _DIS_OffHWND + A_PtrSize
global _DIS_OffRECT  := _DIS_OffHDC  + A_PtrSize

global _ODS_SELECTED    := 0x0001
global _ODS_DISABLED    := 0x0004
global _ODS_FOCUS       := 0x0010
global _ODS_HOTLIGHT    := 0x0040

class ThemeHelper {
    static _btnData         := Map()
    static _brushCache      := Map()
    static _penCache        := Map()
    static _dcBrush         := 0
    static _dcPen           := 0
    static _fgColorRef      := 0
    static _bgBrushRef      := 0
    static _surfaceBrushRef := 0
    static _hooked          := false
    static _dimControls     := Map()
    static _surfaceControls := Map()

    ; Cached GDI pen objects to avoid repeated CreatePen/DeleteObject calls
    static _borderPen    := 0
    static _focusPen     := 0
    static _borderPenRef := 0
    static _focusPenRef  := 0

    ; True while the dark palette is active. Shared helpers use this instead of
    ; hard-coding dark-only behaviour so both themes stay consistent.
    static IsDark() => Theme.IsDark()

    ; Maps a semantic uxtheme role to the class name used by the active theme.
    ; Returns an empty string for the light theme, which restores the system
    ; (light) rendering instead of forcing the DarkMode_* classes.
    static ThemeClass(role) {
        if !this.IsDark()
            return ""

        switch role {
            case "explorer":  return "DarkMode_Explorer"
            case "cfd":       return "DarkMode_CFD"
            case "itemsview": return "DarkMode_ItemsView"
            default:          return "DarkMode_Explorer"
        }
    }

    ; Applies (or clears) a uxtheme class on a window/control.
    static _SetWindowTheme(hwnd, themeClass) {
        if (themeClass == "") {
            ; Empty strings restore the default system theme.
            try DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "wstr", "", "wstr", "")
        } else {
            try DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "wstr", themeClass, "ptr", 0)
        }
    }

    static StyleGui(myGui, variant := "default") {
        myGui.BackColor := (variant == "surface") ? AppState.THEME_SURFACE : AppState.THEME_BG
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        myGui.MarginX := 16
        myGui.MarginY := 16
    }

    static _EnsureHooks() {
        if !this._hooked {
            OnMessage(0x002B, _ThemeHelper_DrawItem)
            OnMessage(0x0133, _ThemeHelper_CtlColorStatic)
            this._hooked := true
        }
    }

    static GetBrush(cref) {
        if !this._brushCache.Has(cref)
            this._brushCache[cref] := DllCall("gdi32\CreateSolidBrush", "uint", cref, "ptr")
        return this._brushCache[cref]
    }

    static GetPen(cref, width := 1) {
        key := cref . ":" . width
        if !this._penCache.Has(key)
            this._penCache[key] := DllCall("gdi32\CreatePen", "int", 0, "int", width, "uint", cref, "ptr")
        return this._penCache[key]
    }

    static StyleButton(ctrl, bgColor := "", fgColor := "", style := "secondary", parentBg := "") {
        if (bgColor = "")
            bgColor := this.ButtonColor(style)
        if (fgColor == "")
            fgColor := this.ButtonTextColor(style)
        if (parentBg == "")
            parentBg := AppState.THEME_BG

        hwnd := ctrl.Hwnd

        try DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "ptr", 0, "ptr", 0)

        wstyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -16, "ptr")
        DllCall("SetWindowLongPtr", "ptr", hwnd, "int", -16, "ptr", wstyle | 0x0000000B)

        cref := this.RgbToColorRef(bgColor)
        this.GetBrush(cref)
        if !this._fgColorRef
            this._fgColorRef := this.RgbToColorRef(AppState.THEME_FG)
        if !this._bgBrushRef
            this._bgBrushRef := this.GetBrush(this.RgbToColorRef(AppState.THEME_BG))

        this._btnData[hwnd] := {
            cref: cref,
            fgRef: this.RgbToColorRef(fgColor),
            parentBgRef: this.RgbToColorRef(parentBg),
            style: style,
            text: ctrl.Text
        }

        this._EnsureHooks()
        ctrl.Redraw()
    }

    static SetButtonStyle(ctrl, style, parentBg := "") {
        if !IsObject(ctrl)
            return
        hwnd := ctrl.Hwnd
        bgColor := this.ButtonColor(style)
        fgColor := this.ButtonTextColor(style)
        if (parentBg == "") {
            parentBgRef := this._btnData.Has(hwnd)
                ? this._btnData[hwnd].parentBgRef
                : this.RgbToColorRef(AppState.THEME_BG)
        } else {
            parentBgRef := this.RgbToColorRef(parentBg)
        }

        cref := this.RgbToColorRef(bgColor)
        this.GetBrush(cref)

        this._btnData[hwnd] := {
            cref: cref,
            fgRef: this.RgbToColorRef(fgColor),
            parentBgRef: parentBgRef,
            style: style,
            text: ctrl.Text
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
            case "primary":    return AppState.THEME_ACCENT_DARK
            case "danger":     return AppState.THEME_DANGER
            case "tonal":      return AppState.THEME_ELEVATED
            case "nav-active": return AppState.THEME_ELEVATED
            case "nav":        return AppState.THEME_BG
            case "surface":    return AppState.THEME_SURFACE
            default:           return AppState.THEME_CONTROL_BG
        }
    }

    ; Foreground for owner-drawn buttons. Accent-filled buttons use the
    ; dedicated on-accent colour so both themes keep readable contrast.
    static ButtonTextColor(style := "secondary") {
        switch style {
            case "primary", "danger":    return AppState.THEME_ON_ACCENT
            case "tonal", "nav-active":  return AppState.THEME_ACCENT_GLOW
            case "nav":                  return AppState.THEME_FG_DIM
            default:                     return AppState.THEME_FG
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
            factor := this.IsDark() ? 0.84 : 0.88
            r := Integer(r * factor)
            g := Integer(g * factor)
            b := Integer(b * factor)
        } else if (state & _ODS_HOTLIGHT) {
            ; Light up on dark surfaces, shade down on light surfaces so the
            ; hover state stays visible in both palettes.
            if this.IsDark() {
                r := Integer(Min(r + 18, 255))
                g := Integer(Min(g + 18, 255))
                b := Integer(Min(b + 18, 255))
            } else {
                r := Integer(Max(r - 12, 0))
                g := Integer(Max(g - 12, 0))
                b := Integer(Max(b - 12, 0))
            }
        }
        return ((b & 0xFF) << 16) | ((g & 0xFF) << 8) | (r & 0xFF)
    }

    static StyleListView(ctrl) {
        this.StyleScrollbar(ctrl)
        headerHwnd := SendMessage(0x101F, 0, 0, ctrl.Hwnd)
        if headerHwnd
            this._SetWindowTheme(headerHwnd, this.ThemeClass("itemsview"))
        ctrl.Redraw()
    }

    static StyleScrollbar(ctrl) {
        if !IsObject(ctrl)
            return

        this._SetWindowTheme(ctrl.Hwnd, this.ThemeClass("explorer"))
        try ctrl.Redraw()
    }

    static StyleEdit(ctrl) {
        if !IsObject(ctrl)
            return

        ; Edit controls without scrollbars use the dark Edit theme. When a
        ; native scrollbar is present, use the Explorer dark theme so the
        ; scrollbar does not fall back to the light system appearance.
        ; The light theme clears both and uses the system appearance.
        style := DllCall("GetWindowLongPtr", "ptr", ctrl.Hwnd, "int", -16, "ptr")
        role := (style & 0x00300000) ? "explorer" : "cfd"

        this._SetWindowTheme(ctrl.Hwnd, this.ThemeClass(role))
        try ctrl.Redraw()
    }

    static StyleComboBox(ctrl) {
        if !IsObject(ctrl)
            return

        ; Apply the same visual family to the ComboBox and its native
        ; drop-down instead of inheriting the contrasting system theme.
        this._SetWindowTheme(ctrl.Hwnd, this.ThemeClass("cfd"))
        try ctrl.Redraw()
    }

    static StyleCheckBox(ctrl, onSurface := false) {
        if !IsObject(ctrl)
            return

        this._SetWindowTheme(ctrl.Hwnd, this.ThemeClass("explorer"))
        if onSurface
            this.MarkSurface(ctrl, AppState.THEME_FG, AppState.THEME_SURFACE)
        try ctrl.Redraw()
    }

    ; Applies the active Google Material theme to a window's DWM chrome,
    ; including smooth Windows 11 rounded corners.
    static ApplyWindowTheme(hwnd) {
        static DWMWA_USE_IMMERSIVE_DARK_MODE := 20
        static DWMWA_WINDOW_CORNER_PREFERENCE := 33
        static DWMWA_BORDER_COLOR := 34
        static DWMWA_CAPTION_COLOR := 35
        static DWMWA_TEXT_COLOR := 36
        static DWMWA_TRANSITIONS_FORCEDISABLED := 3
        static DWMWCP_ROUND := 2

        try DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "ptr", hwnd,
            "int", DWMWA_TRANSITIONS_FORCEDISABLED,
            "int*", 1,
            "int", 4
        )
        try DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "ptr", hwnd,
            "int", DWMWA_USE_IMMERSIVE_DARK_MODE,
            "int*", this.IsDark() ? 1 : 0,
            "int", 4
        )
        try DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "ptr", hwnd,
            "int", DWMWA_WINDOW_CORNER_PREFERENCE,
            "int*", DWMWCP_ROUND,
            "int", 4
        )
        try DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "ptr", hwnd,
            "int", DWMWA_BORDER_COLOR,
            "int*", this.RgbToColorRef(AppState.THEME_BORDER),
            "int", 4
        )
        try DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "ptr", hwnd,
            "int", DWMWA_CAPTION_COLOR,
            "int*", this.RgbToColorRef(AppState.THEME_SURFACE),
            "int", 4
        )
        try DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "ptr", hwnd,
            "int", DWMWA_TEXT_COLOR,
            "int*", this.RgbToColorRef(AppState.THEME_FG),
            "int", 4
        )
    }

    ; Compatibility alias for call sites written before the Light theme.
    static ApplyImmersiveDarkMode(hwnd) => this.ApplyWindowTheme(hwnd)

    static AddButton(myGui, options, label, style := "secondary", parentBg := "") {
        btn := myGui.Add("Button", options " " this.GetButtonOptions(style), label)
        this.StyleButton(btn, this.ButtonColor(style), this.ButtonTextColor(style), style, parentBg)
        return btn
    }

    static GetButtonOptions(style := "secondary", extra := "") {
        return "Background" this.ButtonColor(style)
                . " c" this.ButtonTextColor(style)
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

    ; ListView options without grid lines. Used where rows are separated by
    ; custom drawing instead, which keeps dense lists easier to scan.
    static GetLVOptionsPlain(extra := "") {
        return "Background" AppState.THEME_SURFACE
                . " c" AppState.THEME_FG
                . (extra ? " " extra : "")
    }

    static GetLVOptions(extra := "") {
        return this.GetLVOptionsPlain("Grid" . (extra ? " " extra : ""))
    }

    static GetCheckBoxOptions(extra := "", onSurface := false) {
        bg := onSurface ? AppState.THEME_SURFACE : AppState.THEME_BG
        return "Background" bg
                . " c" AppState.THEME_FG . (extra ? " " extra : "")
    }

    ; Draws a 2px separator with a Google Blue accent lead-in followed by a
    ; clean hairline border. Keeps exact height compatibility with all views.
    static AddSeparator(myGui, width := 600, posY := "") {
        opt := "w" width " h2 Background" AppState.THEME_BORDER
        if (posY != "")
            opt .= " y" posY
        return myGui.Add("Text", opt)
    }

    ; Signature 4-color Google brand accent strip (Blue, Red, Yellow, Green).
    static AddGoogleAccentBar(myGui, x := 0, y := 0, width := 640, height := 3) {
        seg1 := width // 4
        seg2 := width // 4
        seg3 := width // 4
        seg4 := width - seg1 - seg2 - seg3

        c1 := myGui.Add("Text", "x" x " y" y " w" seg1 " h" height " Background" AppState.GOOGLE_BLUE)
        c2 := myGui.Add("Text", "x" (x + seg1) " y" y " w" seg2 " h" height " Background" AppState.GOOGLE_RED)
        c3 := myGui.Add("Text", "x" (x + seg1 + seg2) " y" y " w" seg3 " h" height " Background" AppState.GOOGLE_YELLOW)
        c4 := myGui.Add("Text", "x" (x + seg1 + seg2 + seg3) " y" y " w" seg4 " h" height " Background" AppState.GOOGLE_GREEN)
        return [c1, c2, c3, c4]
    }

    ; Creates a Google Workspace elevated surface card with a 1px border frame.
    static AddSurfaceCard(myGui, x, y, width, height) {
        borderCtrl := myGui.Add(
            "Text",
            "x" x " y" y " w" width " h" height " Background" AppState.THEME_BORDER
        )
        fillCtrl := myGui.Add(
            "Text",
            "x" (x + 1) " y" (y + 1) " w" (width - 2) " h" (height - 2) " Background" AppState.THEME_SURFACE
        )
        return [borderCtrl, fillCtrl]
    }

    ; Creates a 1px horizontal divider inside a surface card.
    static AddCardDivider(myGui, x, y, width) {
        return myGui.Add(
            "Text",
            "x" (x + 1) " y" y " w" (width - 2) " h1 Background" AppState.THEME_BORDER
        )
    }

    static AddTitle(myGui, text, width := 600) {
        myGui.SetFont("s14 Bold c" AppState.THEME_ACCENT, AppState.THEME_FONT)
        ctrl := myGui.Add("Text", "w" width " Background" AppState.THEME_BG, text)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        return ctrl
    }

    static AddSubtitle(myGui, text, width := 600) {
        myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        ctrl := myGui.Add("Text", "w" width " Background" AppState.THEME_BG, text)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        this.MarkDim(ctrl)
        return ctrl
    }

    static MarkDim(ctrl, bgColor := "") {
        if !IsObject(ctrl)
            return
        this._EnsureHooks()
        this._dimControls[ctrl.Hwnd] := (bgColor != "") ? bgColor : AppState.THEME_BG
    }

    static MarkSurface(ctrl, fgColor := "", bgColor := "") {
        if !IsObject(ctrl)
            return
        this._EnsureHooks()
        if (fgColor == "")
            fgColor := AppState.THEME_FG
        if (bgColor == "")
            bgColor := AppState.THEME_SURFACE

        fgRef := this.RgbToColorRef(fgColor)
        bgRef := this.RgbToColorRef(bgColor)
        brush := this.GetBrush(bgRef)

        this._surfaceControls[ctrl.Hwnd] := {
            fgRef: fgRef,
            bgRef: bgRef,
            brush: brush
        }
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
        for key, pen in this._penCache {
            DllCall("gdi32\DeleteObject", "ptr", pen)
        }
        for cref, brush in this._brushCache {
            DllCall("gdi32\DeleteObject", "ptr", brush)
        }
        this._dimControls := Map()
        this._surfaceControls := Map()
        this._brushCache := Map()
        this._penCache := Map()
        this._fgColorRef := 0
        this._bgBrushRef := 0
        this._surfaceBrushRef := 0
    }

    ; Drop everything derived from the previously active palette. Buttons and
    ; text caches are rebuilt lazily with the new colours.
    static RefreshThemeResources() {
        this.ReleaseResources()
        this._btnData := Map()
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

    if !ThemeHelper._dcBrush
        ThemeHelper._dcBrush := DllCall("GetStockObject", "Int", 18, "Ptr")

    ; 1. Clear full button bounds with the parent surface background so rounded
    ; corners blend cleanly without square corner artifacts.
    parentBgRef := data.HasProp("parentBgRef")
        ? data.parentBgRef
        : ThemeHelper.RgbToColorRef(AppState.THEME_BG)
    DllCall("SetDCBrushColor", "Ptr", hdc, "UInt", parentBgRef)
    DllCall("FillRect", "Ptr", hdc, "Ptr", rcPtr, "Ptr", ThemeHelper._dcBrush)

    style := data.HasProp("style") ? data.style : "secondary"

    ; 2. Compute fill and border colours according to Google Material button role.
    if (style == "nav") {
        if (itemState & _ODS_SELECTED)
            fillColor := ThemeHelper.RgbToColorRef(AppState.THEME_ELEVATED)
        else if (itemState & _ODS_HOTLIGHT)
            fillColor := ThemeHelper.RgbToColorRef(AppState.THEME_CONTROL_HOVER)
        else
            fillColor := parentBgRef
        borderColor := fillColor
    } else if (style == "nav-active") {
        fillColor := ThemeHelper.ShadeColor(ThemeHelper.RgbToColorRef(AppState.THEME_ELEVATED), itemState)
        borderColor := fillColor
    } else if (style == "primary" || style == "danger") {
        fillColor := ThemeHelper.ShadeColor(data.cref, itemState)
        borderColor := (itemState & _ODS_FOCUS)
            ? ThemeHelper.RgbToColorRef(AppState.THEME_ACCENT)
            : fillColor
    } else if (style == "tonal") {
        fillColor := ThemeHelper.ShadeColor(data.cref, itemState)
        borderColor := (itemState & (_ODS_FOCUS | _ODS_HOTLIGHT))
            ? ThemeHelper.RgbToColorRef(AppState.THEME_ACCENT)
            : fillColor
    } else {
        fillColor := ThemeHelper.ShadeColor(data.cref, itemState)
        borderColor := (itemState & (_ODS_FOCUS | _ODS_HOTLIGHT))
            ? ThemeHelper.RgbToColorRef(AppState.THEME_ACCENT)
            : ThemeHelper.RgbToColorRef(AppState.THEME_BORDER)
    }

    ; 3. Draw rounded pill / button shape using GDI RoundRect.
    radius := (style == "nav" || style == "nav-active" || style == "tonal") ? 16 : 12
    fillBrush := ThemeHelper.GetBrush(fillColor)
    borderPen := ThemeHelper.GetPen(borderColor, 1)

    oldBrush := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", fillBrush, "ptr")
    oldPen   := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", borderPen, "ptr")
    DllCall(
        "gdi32\RoundRect",
        "ptr", hdc,
        "int", rcLeft,
        "int", rcTop,
        "int", rcRight,
        "int", rcBot,
        "int", radius,
        "int", radius
    )
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldBrush, "ptr")
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen, "ptr")

    ; 4. Active Google Navigation Pill indicator bar on the left edge.
    if (style == "nav-active") {
        indBar := Buffer(16, 0)
        NumPut("Int", rcLeft + 4, indBar, 0)
        NumPut("Int", rcTop + 8,  indBar, 4)
        NumPut("Int", rcLeft + 8, indBar, 8)
        NumPut("Int", rcBot - 8,  indBar, 12)
        DllCall("SetDCBrushColor", "Ptr", hdc, "UInt", ThemeHelper.RgbToColorRef(AppState.THEME_ACCENT))
        DllCall("FillRect", "Ptr", hdc, "Ptr", indBar, "Ptr", ThemeHelper._dcBrush)
    }

    ; 5. Draw button label.
    if (itemState & _ODS_DISABLED) {
        txtColor := ThemeHelper.RgbToColorRef(AppState.THEME_FG_MUTED)
    } else if (style == "nav" && (itemState & _ODS_HOTLIGHT)) {
        txtColor := ThemeHelper.RgbToColorRef(AppState.THEME_FG)
    } else {
        txtColor := (data.HasProp("fgRef") && data.fgRef) ? data.fgRef : ThemeHelper._fgColorRef
    }

    DllCall("gdi32\SetTextColor", "ptr", hdc, "uint", txtColor)
    DllCall("gdi32\SetBkMode", "ptr", hdc, "int", 1)

    hFont   := DllCall("gdi32\GetStockObject", "int", 17, "ptr")
    oldFont := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", hFont, "ptr")

    if (style == "nav" || style == "nav-active") {
        txtRect := Buffer(16, 0)
        NumPut("Int", rcLeft + 16, txtRect, 0)
        NumPut("Int", rcTop,       txtRect, 4)
        NumPut("Int", rcRight - 8, txtRect, 8)
        NumPut("Int", rcBot,       txtRect, 12)
        DllCall("user32\DrawTextW", "ptr", hdc, "str", data.text, "int", -1, "ptr", txtRect, "uint", 0x24)
    } else {
        DllCall("user32\DrawTextW", "ptr", hdc, "str", data.text, "int", -1, "ptr", rcPtr, "uint", 0x25)
    }

    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldFont, "ptr")

    return 1
}

_ThemeHelper_CtlColorStatic(wParam, lParam, msg, hwnd) {
    if ThemeHelper._surfaceControls.Has(lParam) {
        info := ThemeHelper._surfaceControls[lParam]
        DllCall("gdi32\SetTextColor", "ptr", wParam, "uint", info.fgRef)
        DllCall("gdi32\SetBkColor", "ptr", wParam, "uint", info.bgRef)
        return info.brush
    }

    if ThemeHelper._dimControls.Has(lParam) {
        bgHex := ThemeHelper._dimControls[lParam]
        txtRef := ThemeHelper.RgbToColorRef(AppState.THEME_FG_DIM)
        bgRef  := ThemeHelper.RgbToColorRef(bgHex)
        DllCall("gdi32\SetTextColor", "ptr", wParam, "uint", txtRef)
        DllCall("gdi32\SetBkColor", "ptr", wParam, "uint", bgRef)
        return ThemeHelper.GetBrush(bgRef)
    }

    return ""
}
