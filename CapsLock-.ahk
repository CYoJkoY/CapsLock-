#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

FileInstall("lang.csv", A_ScriptDir "\lang.csv", 1)

;@Ahk2Exe-AddResource assets\AlwaysOnTopOn.wav, SND_ON
;@Ahk2Exe-AddResource assets\AlwaysOnTopOff.wav, SND_OFF

#Include "Utils\Language.ahk"
#Include "Utils\ResourceSound.ahk"
#Include "Utils\MethodsUtils.ahk"
#Include "Utils\DarkInputDialog.ahk"
#Include "Utils\WindowUtils.ahk"
#Include "Utils\PandocUtils.ahk"

#Include "Config\Globals.ahk"
#Include "Config\Encryption.ahk"
#Include "Config\ConfigManager.ahk"
#Include "Config\PromptManager.ahk"
#Include "Config\SecureIni.ahk"

#Include "Core\Clipboard.ahk"
#Include "Core\ClipboardPaste.ahk"
#Include "Core\FileValidation.ahk"
#Include "Core\FileOperations.ahk"
#Include "Core\ImageToPdf.ahk"
#Include "Core\Cleanup.ahk"
#Include "Core\Pandoc.ahk"
#Include "Core\ApiJsonHelper.ahk"
#Include "Core\ApiRequestBuilder.ahk"
#Include "Core\ApiResponseParser.ahk"
#Include "Core\ApiStreamHandler.ahk"
#Include "Core\ApiClient.ahk"
#Include "Core\GistSync.ahk"

#Include "History\HistoryStorage.ahk"
#Include "History\HistoryMenu.ahk"
#Include "History\HistoryPaste.ahk"
#Include "History\FullHistoryGui.ahk"
#Include "History\FullHistoryHandlers.ahk"
#Include "History\CustomMenu.ahk"

#Include "Hotkeys\HotkeyBindings.ahk"
#Include "Hotkeys\HotkeyActions.ahk"
#Include "Hotkeys\PasteHandler.ahk"
#Include "Hotkeys\ApiAction.ahk"

#Include "Tray\TrayMenu.ahk"
#Include "Tray\TraySettings.ahk"

#Include "UI\OSD.ahk"
#Include "UI\PreviewGui.ahk"
#Include "UI\ThemeHelper.ahk"
#Include "UI\PromptEditDialog.ahk"
#Include "UI\PromptSettingsGui.ahk"
#Include "UI\GistSyncGui.ahk"

Language.Load()
ConfigManager.Load()
PromptManager.Load()
HistoryManager.Load()
FileHelper.BuildIgnoreRegexes()

if AppState.AutoCleanEnabled
    SetTimer(AutoCleanHistory, 60000)

TraySetup()
OnClipboardChange(ClipboardChanged)

OnExit((*) => (
    HistoryManager.ForceSave(),
    CleanupManager.OnExit()
))
