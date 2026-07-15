#Requires AutoHotkey v2.0

class AppState {
    static History := []
    static MaxHistory := 10000
    static TargetWindow := 0
    static PasteMode := 1
    static DeleteMode := 1
    static DeleteDelay := 10
    static CleanupInterval := 30
    static LastManualClipboard := ""
    static IgnoreNextClipChange := false
    static FullHistoryGui := ""
    static MenuPosX := 0
    static MenuPosY := 0
    static SelectedIndex := 0
    static SelectedItem := ""
    static ImageMagickExe := ""
    static ConfigFile := A_ScriptDir "\configs\Config.ini"
    static HistoryFile := A_ScriptDir "\configs\ClipHistory.bin"
    static ENCRYPT_KEY := 0x5A
    static MAX_VISIBLE_MENU := 15
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
    static PendingCleanup := []
    static CleanupTimer := ""
    static TrayMenu := ""
    static modeMenu := ""
    static pasteModeMenu := ""
    static currentImMenuText := ""
    static IgnorePatterns := []
}
