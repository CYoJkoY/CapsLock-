#Requires AutoHotkey v2.0

class AppState {
    ; --- Core Data ---
    static History := []
    static MaxHistory := 10000
    static TargetWindow := 0

    ; --- Settings ---
    static PasteMode := 1
    static DeleteMode := 1
    static DeleteDelay := 10
    static CleanupInterval := 30

    ; --- Runtime State ---
    static LastManualClipboard := ""
    static IgnoreNextClipChange := false
    static FullHistoryGui := ""
    static MenuPosX := 0
    static MenuPosY := 0
    static ImageMagickExe := ""

    ; --- Language ---
    static CurrentLanguage := ""

    ; --- Paths ---
    static ConfigFile := A_ScriptDir "\configs\Config.ini"
    static HistoryFile := A_ScriptDir "\configs\ClipHistory.bin"
    static ENCRYPT_KEY := 0x5A
    static _init := DirExist(A_ScriptDir "\configs") ? "" : DirCreate(A_ScriptDir "\configs")

    ; --- UI Constants ---
    static MAX_VISIBLE_MENU := 12
    static MAX_FULL_HISTORY_DISPLAY := 50

    ; --- UI Theme ---
    static THEME_BG            := "0x14141D"
    static THEME_SURFACE       := "0x1B1B27"
    static THEME_ELEVATED      := "0x232332"
    static THEME_CONTROL_BG    := "0x282838"
    static THEME_CONTROL_HOVER := "0x33334A"
    static THEME_BORDER        := "0x3A3A52"

    static THEME_FG            := "0xB0B4CC"
    static THEME_FG_DIM        := "0x8088A0"
    static THEME_FG_MUTED      := "0x5E6478"

    static THEME_ACCENT        := "0x5B86C9"
    static THEME_ACCENT_DARK   := "0x3A5A8C"
    static THEME_ACCENT_GLOW   := "0x82A8E0"

    static THEME_SUCCESS       := "0x6FA572"
    static THEME_WARNING       := "0xC4A95E"
    static THEME_DANGER        := "0xC06070"

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

    ; --- Ignore / Auto Clean ---
    static IgnorePatterns := []
    static AutoCleanEnabled := false
    static MaxHistoryItems := 500
}
