#Requires AutoHotkey v2.0

class ThemeHelper {

    static StyleGui(myGui, variant := "default") {
        myGui.BackColor := AppState.THEME_BG
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        myGui.MarginX := 16
        myGui.MarginY := 16
    }

    static ApplyImmersiveDarkMode(hwnd) {
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "Int*", 1, "Int", 4)
        }

        try {
            borderColor := Integer("0x" SubStr(AppState.THEME_BORDER, 3))
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 34, "Int*", borderColor, "Int", 4)
        }

        try {
            captionColor := Integer("0x" SubStr(AppState.THEME_SURFACE, 3))
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 35, "Int*", captionColor, "Int", 4)
        }

        try {
            textColor := Integer("0x" SubStr(AppState.THEME_FG, 3))
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 36, "Int*", textColor, "Int", 4)
        }
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

    static GetButtonPrimary(extra := "") {
        return "Background" AppState.THEME_ACCENT_DARK
            . " cWhite"
            . (extra ? " " extra : "")
    }

    static GetButtonSecondary(extra := "") {
        return "Background" AppState.THEME_CONTROL_BG
            . " c" AppState.THEME_FG
            . (extra ? " " extra : "")
    }

    static GetButtonDanger(extra := "") {
        return "Background" AppState.THEME_DANGER
            . " cWhite"
            . (extra ? " " extra : "")
    }

    static GetButtonOptions(extra := "") {
        return this.GetButtonSecondary(extra)
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
