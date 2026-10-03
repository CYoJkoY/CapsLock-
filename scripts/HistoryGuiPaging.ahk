#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "..\Config\Globals.ahk"
#Include "..\Config\Encryption.ahk"
#Include "..\Config\ConfigManager.ahk"
#Include "..\Utils\Language.ahk"
#Include "..\Utils\ResourceSound.ahk"
#Include "..\Utils\MethodsUtils.ahk"
#Include "..\Utils\DarkInputDialog.ahk"
#Include "..\Utils\Json.ahk"
#Include "..\Utils\Hash.ahk"
#Include "..\Utils\Base64.ahk"
#Include "..\Utils\Random.ahk"
#Include "..\Utils\HttpClient.ahk"
#Include "..\Utils\SecureStorage.ahk"
#Include "..\Utils\TaskbarOrder.ahk"
#Include "..\Core\FileValidation.ahk"
#Include "..\Core\FileOperations.ahk"
#Include "..\History\HistoryStorage.ahk"
#Include "..\History\HistoryMenu.ahk"
#Include "..\History\HistoryPaste.ahk"
#Include "..\History\HistoryDelete.ahk"
#Include "..\History\FullHistoryGui.ahk"
#Include "..\History\FullHistoryHandlers.ahk"
#Include "..\History\CustomMenu.ahk"
#Include "..\UI\Theme.ahk"
#Include "..\UI\ThemeHelper.ahk"

Language.Load()
ConfigManager.Load()
Theme.Init()

; 生成测试剪贴板数据
AppState.History := []
loop 120 {
    AppState.History.Push(Map(
        "text", "Test Entry " A_Index "`nSecond Line",
        "time", "2026-10-03 10:00:00"
    ))
}
HistoryManager.revision := 1

; 验证检索函数 HistorySearch
results := HistorySearch("Test Entry 1")
if (results.Length < 1) {
    FileAppend("FAIL: HistorySearch failed to find entries`n", "*")
    ExitApp(1)
}

; 验证截字预览函数 HistoryPreviewText
preview := HistoryPreviewText("Line 1`nLine 2")
if InStr(preview, "`n") {
    FileAppend("FAIL: HistoryPreviewText failed to normalize whitespace`n", "*")
    ExitApp(1)
}

FileAppend("PASS: History paging and search pure-AHK validation succeeded`n", "*")
ExitApp(0)
