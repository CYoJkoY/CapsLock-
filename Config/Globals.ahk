#Requires AutoHotkey v2.0

class AppState {
    ; ---  Core Data ---
    static History := []
    static MaxHistory := 10000
    static TargetWindow := 0

    ; --- Settings ---
    static PasteMode := 1  ; 1 = File, 2 = Text
    static DeleteMode := 1  ; 1 = Delay, 2 = Batch, 3 = Never
    static DeleteDelay := 10
    static CleanupInterval := 30

    ; --- Runtime State ---
    static LastManualClipboard := ""
    static IgnoreNextClipChange := false
    static FullHistoryGui := ""
    static MenuPosX := 0
    static MenuPosY := 0
    static SelectedIndex := 0
    static SelectedItem := ""
    static ImageMagickExe := ""

    ; --- Paths ---
    static ConfigFile := A_ScriptDir "\configs\Config.ini"
    static HistoryFile := A_ScriptDir "\configs\ClipHistory.bin"
    static ENCRYPT_KEY := 0x5A

    static _init := DirExist(A_ScriptDir "\configs") ? "" : DirCreate(A_ScriptDir "\configs")

    ; --- UI Constants ---
    static MAX_VISIBLE_MENU := 15
    static MAX_FULL_HISTORY_DISPLAY := 50

    ; --- UI Theme (Refined Dark) ---
    static THEME_BG            := "0x1E1E2E"
    static THEME_SURFACE       := "0x262637"
    static THEME_ELEVATED      := "0x2E2E42"
    static THEME_CONTROL_BG    := "0x313244"
    static THEME_CONTROL_HOVER := "0x3E3E56"
    static THEME_BORDER        := "0x45475A"
    static THEME_FG            := "0xCDD6F4"
    static THEME_FG_DIM        := "0xA6ADC8"
    static THEME_FG_MUTED      := "0x7F849C"
    static THEME_ACCENT        := "0x89B4FA"
    static THEME_ACCENT_DARK   := "0x45608A"
    static THEME_ACCENT_GLOW   := "0xB4D0FB"
    static THEME_SUCCESS       := "0xA6E3A1"
    static THEME_WARNING       := "0xF9E2AF"
    static THEME_DANGER        := "0xF38BA8"
    static THEME_FONT          := "Segoe UI"
    static THEME_FONT_MONO     := "Cascadia Code"
    static THEME_RADIUS        := 8

    ; --- File Types ---
    static TextFormats := [
        "txt", "log", "md", "rtf",
        "tex", "wri", "ini", "cfg",
        "json", "xml", "yaml", "yml",
        "toml", "properties", "env",
        "c", "cpp", "cxx", "h", "js",
        "ts", "html", "htm", "css", "php",
        "jsp", "asp", "apsx", "vue", "scss",
        "sass", "less", "py", "java", "go",
        "rs", "rb", "kt", "cs", "sql", "r",
        "lua", "vb", "bat", "cmd", "sh", "ps1",
        "gd", "gdshader", "tres", "tscn"
    ]
    static ImageFormats := [
        "png", "jpg", "jpeg", "bmp",
        "gif", "tiff", "tif", "webp",
        "ico", "heic"
    ]

    ; --- Cleanup ---
    static PendingCleanup := []
    static CleanupTimer := ""

    ; --- Menus ---
    static TrayMenu := ""
    static modeMenu := ""
    static pasteModeMenu := ""
    static currentImMenuText := ""
    static IgnorePatterns := []
    static AutoCleanEnabled := false
    static MaxHistoryItems := 500
}
