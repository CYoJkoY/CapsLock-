#Requires AutoHotkey v2.0

global lastManualClipboard := ""
global clipboardHistory := []
global maxHistory := 10000
global ignoreNextClipChange := false

global MAX_VISIBLE_MENU := 15
global fullHistoryGui := ""
global menuPosX := 0
global menuPosY := 0
global selectedIndex := 0
global selectedItem := ""

global historyFile := A_ScriptDir "\configs\ClipHistory.bin"
global configFile := A_ScriptDir "\configs\Config.ini"
global targetWindow := 0

global ENCRYPT_KEY := 0x5A

global TextFormats := [
    "txt",
    "log",
    "md",
    "rtf",
    "tex",
    "wri",
    "ini",
    "cfg",
    "json",
    "xml",
    "yaml",
    "yml",
    "toml",
    "properties",
    "env",
    "c",
    "cpp",
    "cxx",
    "h",
    "js",
    "ts",
    "html",
    "htm",
    "css",
    "php",
    "jsp",
    "asp",
    "apsx",
    "vue",
    "scss",
    "sass",
    "less",
    "py",
    "java",
    "go",
    "rs",
    "rb",
    "kt",
    "cs",
    "sql",
    "r",
    "lua",
    "vb",
    "bat",
    "cmd",
    "sh",
    "ps1",
    "gd",
    "gdshader",
    "tres",
    "tscn"
]
global ImageFormats := [
    "png",
    "jpg",
    "jpeg",
    "bmp",
    "gif",
    "tiff",
    "tif",
    "webp",
    "ico",
    "heic"
]

global imageMagickExe := ""

global deleteMode := 1
global deleteDelay := 10
global cleanupInterval := 30
global pendingCleanupFiles := []
global batchCleanupTimer := ""

global pasteMode := 1

global modeMenu := Menu()
global pasteModeMenu := Menu()
global currentImMenuText := "ImageMagick: Not Set"
