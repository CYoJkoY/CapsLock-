#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================== TrayIcon =========================== ;
A_IconTip := "CapsLock-"
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Load on start up", ToggleAutoStart)
Tray.Add("Reload", (*) => Reload())
Tray.Add("Exit", (*) => ExitApp())

if IsAutoStartEnabled()
    Tray.Check("Load on start up")

ToggleAutoStart(*) {
    RegPath := "Software\Microsoft\Windows\CurrentVersion\Run"
    AppName := "CapsLockExtension"

    if IsAutoStartEnabled() {
        RegDelete "HKEY_CURRENT_USER\" RegPath, AppName
        Tray.Uncheck "Load on start up"
        MsgBox "Load on start up turn off", "Success", "Iconi T2"
    } else {
        RegWrite '"' A_ScriptFullPath '"', "REG_SZ", "HKEY_CURRENT_USER\" RegPath, AppName
        Tray.Check "Load on start up"
        MsgBox "Load on start up turn on", "Success", "Iconi T2"
    }
}

IsAutoStartEnabled() {
    try {
        RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "CapsLockExtension")
        return true
    } catch {
        return false
    }
}

; =========================== Extension =========================== ;
*CapsLock:: {
    if !(A_PriorKey = "CapsLock")
        return

    if (A_TimeSincePriorHotkey > 300 || A_TimeSincePriorHotkey < 50)
        return

    if GetKeyState("CapsLock", "T")
        SetCapsLockState "AlwaysOff"
    else
        SetCapsLockState "AlwaysOn"
}

; =========================== Custom =========================== ;
#HotIf GetKeyState("CapsLock", "P")

Left:: Send "^{Left}"
Right:: Send "^{Right}"
Up:: Send "{Home}"
Down:: Send "{End}"

+Left:: Send "^+{Left}"
+Right:: Send "^+{Right}"
+Up:: Send "+{Home}"
+Down:: Send "+{End}"

Space:: Send "^{Left}^+{Right}"

,:: Send "{Backspace}"
.:: Send "{Delete}"
m:: Send "^{Backspace}"
/:: Send "^{Delete}"
Backspace:: Send "{Home}+{End}{Delete}"
Delete:: Send "{Home}+{End}{Delete}"

E:: Send "^{PgDn}"
Q:: Send "^{PgUp}"

LButton:: {
    AdjustOpacity(20)
    if KeyWait("LButton", "T0.3")
        return

    while GetKeyState("LButton", "P") {
        AdjustOpacity(5)
        Sleep 50
    }
}

RButton:: {
    AdjustOpacity(-20)
    if KeyWait("RButton", "T0.3")
        return

    while GetKeyState("RButton", "P") {
        AdjustOpacity(-5)
        Sleep 50
    }
}

MButton:: {
    hwnd := WinExist("A")
    currentTrans := WinGetTransparent(hwnd)

    if (currentTrans = "" || currentTrans = 255) {
        WinSetTransparent(10, hwnd)
    } else {
        WinSetTransparent(255, hwnd)
    }
}

8::
Numpad8:: {
    if WinGetMinMax("A") = 1
        WinRestore "A"
    else
        WinMaximize "A"
}

2::
Numpad2:: WinMinimize "A"

#HotIf

; =========================== Method =========================== ;
AdjustOpacity(step) {
    try {
        hwnd := WinExist("A")
        currentTrans := WinGetTransparent(hwnd)

        if (currentTrans = "")
            currentTrans := 255

        newTrans := Clamp(currentTrans + step, 20, 255)
        WinSetTransparent(newTrans, hwnd)
    } catch {
        return
    }
}

Clamp(val, min, max) => (val < min) ? min : (val > max) ? max : val
