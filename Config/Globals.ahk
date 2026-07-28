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

    ; --- UI Constants ---
    static MAX_VISIBLE_MENU := 15
    static MAX_FULL_HISTORY_DISPLAY := 50

    ; --- UI Theme ---
    static THEME_BG := "0x1E1E1E"
    static THEME_CONTROL_BG := "0x252526"
    static THEME_FG := "0xD4D4D4"
    static THEME_ACCENT := "0x007ACC"
    static THEME_FONT := "Segoe UI"

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
}
