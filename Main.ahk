#Requires AutoHotkey v2.0
#SingleInstance Force

A_HotkeyInterval := 2000
A_MaxHotkeysPerInterval := 200

; === Module includes ===
#Include Constants.ahk
#Include Encryption.ahk
#Include Config.ahk
#Include Cleanup.ahk
#Include ClipboardUtils.ahk
#Include History.ahk
#Include Hotkeys.ahk
#Include Tray.ahk

LoadHistory()
LoadConfig()
TraySetup()
OnClipboardChange(HandleHistoryUpdate)
