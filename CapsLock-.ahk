#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-AddResource assets\AlwaysOnTopOn.wav, SND_ON
;@Ahk2Exe-AddResource assets\AlwaysOnTopOff.wav, SND_OFF

A_HotkeyInterval := 2000
A_MaxHotkeysPerInterval := 200

#Include "Config/Globals.ahk"
#Include "Config/Encryption.ahk"
#Include "Config/ConfigManager.ahk"

#Include "Core/Clipboard.ahk"
#Include "Core/ClipboardPaste.ahk"
#Include "Core/FileValidation.ahk"
#Include "Core/FileOperations.ahk"
#Include "Core/ImageToPdf.ahk"
#Include "Core/Cleanup.ahk"
#Include "Core/WindowUtils.ahk"

#Include "History/HistoryStorage.ahk"
#Include "History/HistoryMenu.ahk"
#Include "History/HistoryFullGui.ahk"
#Include "History/HistoryActions.ahk"

#Include "Hotkeys/HotkeyBindings.ahk"
#Include "Hotkeys/HotkeyActions.ahk"
#Include "Tray/TrayMenu.ahk"
#Include "Tray/TraySettings.ahk"

#Include "UI/OSD.ahk"
#Include "UI/PreviewGui.ahk"
#Include "Utils/ResourceSound.ahk"

LoadHistory()
LoadConfig()
TraySetup()
OnClipboardChange( HandleHistoryUpdate )
