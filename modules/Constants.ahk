#Requires AutoHotkey v2.0

global LastManualClipboard := ""
global ClipboardHistory := []
global MaxHistory := 10000
global MAX_VISIBLE_MENU := 15
global FullHistoryGui := ""
global MenuPosX := 0
global MenuPosY := 0
global SelectedIndex := 0
global SelectedItem := ""
global HistoryFile := A_ScriptDir "\ClipHistory.bin"
global TargetWindow := 0
global ENCRYPT_KEY := 0x5A
global ImageMagickExe := ""
global ImageFormats := ["png", "jpg", "jpeg", "bmp", "gif", "tiff", "tif", "webp", "ico", "heic"]
global IgnoreNextClipChange := false
global DeleteMode := 1
global DeleteDelay := 10
global CleanupInterval := 30
global PendingCleanupFiles := []
global ConfigFile := A_ScriptDir "\Config.ini"
global BatchCleanupTimer := ""
global PasteMode := 1
global ModeMenu := Menu()
global PasteModeMenu := Menu()
global CurrentImMenuText := "ImageMagick: Not Set"
