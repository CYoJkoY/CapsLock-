#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-AddResource assets\AlwaysOnTopOn.wav, SND_ON
;@Ahk2Exe-AddResource assets\AlwaysOnTopOff.wav, SND_OFF

A_HotkeyInterval := 2000
A_MaxHotkeysPerInterval := 200

#Include modules\Constants.ahk
#Include modules\Encryption.ahk
#Include modules\Config.ahk
#Include modules\Cleanup.ahk
#Include modules\ClipboardManager.ahk
#Include modules\History.ahk
#Include modules\Hotkeys.ahk
#Include modules\Tray.ahk
#Include modules\Window.ahk

LoadHistory()
LoadConfig()
TraySetup()
OnClipboardChange(HandleHistoryUpdate)

PlayResourceSound(resourceName) {
    hModule := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")

    hResInfo := DllCall("FindResource", "Ptr", hModule, "Str", resourceName, "UInt", 10, "Ptr")
    if !hResInfo
        return

    resSize := DllCall("SizeofResource", "Ptr", hModule, "Ptr", hResInfo, "UInt")
    hResData := DllCall("LoadResource", "Ptr", hModule, "Ptr", hResInfo, "Ptr")
    pResource := DllCall("LockResource", "Ptr", hResData, "Ptr")

    if !pResource
        return

    DllCall("winmm\PlaySoundW", "Ptr", pResource, "Ptr", 0, "UInt", 0x5)
}
