#Requires AutoHotkey v2.0

class ThemeHelper {
    static ApplyImmersiveDarkMode(hwnd) {
        ; DWMWA_USE_IMMERSIVE_DARK_MODE = 20
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "Int*", 1, "Int", 4)
        }
    }

    static GetEditOptions() {
        return "Background" AppState.THEME_CONTROL_BG " c" AppState.THEME_FG
    }

    static GetLVOptions() {
        return "Background" AppState.THEME_CONTROL_BG " c" AppState.THEME_FG
    }

    static GetButtonOptions() {
        return "Background" AppState.THEME_CONTROL_BG " c" AppState.THEME_FG
    }

    static GetCheckBoxOptions() {
        return "c" AppState.THEME_FG
    }

    static StyleGui(myGui) {
        myGui.BackColor := AppState.THEME_BG
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
    }
}
