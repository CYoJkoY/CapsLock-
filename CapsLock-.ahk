#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

;@Ahk2Exe-AddResource assets\AlwaysOnTopOn.wav, SND_ON
;@Ahk2Exe-AddResource assets\AlwaysOnTopOff.wav, SND_OFF

#Include "Config\Globals.ahk"
#Include "Config\Encryption.ahk"
#Include "Config\ConfigManager.ahk"

#Include "Core\Clipboard.ahk"
#Include "Core\ClipboardPaste.ahk"
#Include "Core\FileValidation.ahk"
#Include "Core\FileOperations.ahk"
#Include "Core\ImageToPdf.ahk"
#Include "Core\Cleanup.ahk"
#Include "Core\WindowUtils.ahk"

#Include "History\HistoryStorage.ahk"
#Include "History\HistoryMenu.ahk"
#Include "History\HistoryPaste.ahk"
#Include "History\HistoryDelete.ahk"
#Include "History\FullHistoryGui.ahk"
#Include "History\FullHistoryHandlers.ahk"

#Include "Hotkeys\HotkeyBindings.ahk"
#Include "Hotkeys\HotkeyActions.ahk"
#Include "Hotkeys\PasteHandler.ahk"

#Include "Tray\TrayMenu.ahk"
#Include "Tray\TraySettings.ahk"

#Include "UI\OSD.ahk"
#Include "UI\PreviewGui.ahk"

#Include "Utils\ResourceSound.ahk"
#Include "Utils\MethodsUtils.ahk"

HistoryManager.Load()
ConfigManager.Load()
TraySetup()
OnClipboardChange( OnClipboardChange )
OnExit( CleanupManager.OnExit )
