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
#Include "Utils\Json.ahk"
#Include "Utils\Hash.ahk"
#Include "Utils\HttpClient.ahk"
#Include "Utils\SecureStorage.ahk"

#Include "Config\Globals.ahk"
#Include "Config\Encryption.ahk"
#Include "Config\ConfigManager.ahk"
#Include "Core\QuickPhraseStore.ahk"
#Include "Core\CloudSyncIdentity.ahk"
#Include "Core\CloudSyncCredentials.ahk"
#Include "Core\CloudSyncState.ahk"
#Include "Core\CloudSyncModel.ahk"
#Include "Core\CloudSyncSerializer.ahk"
#Include "Core\CloudSyncMerger.ahk"
#Include "Core\CloudSyncStorage.ahk"
#Include "Core\CloudSyncProvider.ahk"
#Include "Core\CloudSyncProviderFactory.ahk"
#Include "Core\CloudSyncCoordinator.ahk"
#Include "Core\Providers\GitHubGistProvider.ahk"

#Include "Core\Clipboard.ahk"
#Include "Core\ClipboardPaste.ahk"
#Include "Core\FileValidation.ahk"
#Include "Core\FileOperations.ahk"
#Include "Core\ImageToPdf.ahk"
#Include "Core\Cleanup.ahk"
#Include "Core\WindowUtils.ahk"
#Include "Core\WindowHole.ahk"
#Include "Core\Pandoc.ahk"

#Include "History\HistoryStorage.ahk"
#Include "History\HistoryMenu.ahk"
#Include "History\HistoryPaste.ahk"
#Include "History\HistoryDelete.ahk"
#Include "History\FullHistoryGui.ahk"
#Include "History\FullHistoryHandlers.ahk"
#Include "History\CustomMenu.ahk"

#Include "UI\Cheatsheet.ahk"

#Include "Hotkeys\HotkeyBindings.ahk"
#Include "Hotkeys\HotkeyActions.ahk"
#Include "Hotkeys\PasteHandler.ahk"
#Include "Hotkeys\HotkeyReference.ahk"

#Include "Tray\TrayMenu.ahk"
#Include "Tray\TraySettings.ahk"

#Include "UI\OSD.ahk"
#Include "UI\PreviewGui.ahk"
#Include "UI\ThemeHelper.ahk"
#Include "UI\WindowSwitcherGui.ahk"
#Include "UI\CloudSyncGui.ahk"
#Include "UI\CloudSyncConflictGui.ahk"
#Include "UI\QuickPhraseGui.ahk"

Language.Load()
ConfigManager.Load()
HistoryManager.Load()
QuickPhraseStore.Load()
FileHelper.BuildIgnoreRegexes()

if AppState.AutoCleanEnabled
    SetTimer(AutoCleanHistory, 60000)

TraySetup()
OnClipboardChange(ClipboardChanged)

OnExit((*) => (
    CloudSyncCoordinator.Shutdown(),
    WindowHole.Stop(),
    HistoryManager.ForceSave(),
    CleanupManager.OnExit()
))
