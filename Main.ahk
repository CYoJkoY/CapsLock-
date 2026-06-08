#Requires AutoHotkey v2.0
#SingleInstance Force

A_HotkeyInterval := 2000
A_MaxHotkeysPerInterval := 200

FileInstall("assets\AlwaysOnTopOn.wav", "assets\AlwaysOnTopOn.wav", 0)
FileInstall("assets\AlwaysOnTopOff.wav", "assets\AlwaysOnTopOff.wav", 0)

; === Module includes ===
#Include modules\Constants.ahk
#Include modules\Encryption.ahk
#Include modules\Config.ahk
#Include modules\Cleanup.ahk
#Include modules\ClipboardUtils.ahk
#Include modules\History.ahk
#Include modules\Hotkeys.ahk
#Include modules\Tray.ahk

LoadHistory()
LoadConfig()
TraySetup()
OnClipboardChange(HandleHistoryUpdate)
