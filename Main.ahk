#Requires AutoHotkey v2.0
#SingleInstance Force

A_HotkeyInterval := 2000
A_MaxHotkeysPerInterval := 200

ExtractResource("assets\AlwaysOnTopOn.wav", A_ScriptDir "\assets", "AlwaysOnTopOn.wav")
ExtractResource("assets\AlwaysOnTopOff.wav", A_ScriptDir "\assets", "AlwaysOnTopOff.wav")

; === Module includes ===
#Include modules\Methods.ahk
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
