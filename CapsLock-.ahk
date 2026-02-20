#Requires AutoHotkey v2.0
#SingleInstance Force

global LastManualClipboard := ""
global ClipboardHistory := []
global MaxHistory := 50
global MenuPosX := 0
global MenuPosY := 0

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

OnClipboardChange(HandleHistoryUpdate)

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

v:: {
    global LastManualClipboard

    currentClip := A_Clipboard

    if (currentClip != "" && !InStr(currentClip, A_Temp "\ClipTemp_")) {
        LastManualClipboard := currentClip
    }

    targetText := (LastManualClipboard != "") ? LastManualClipboard : currentClip
    if (targetText == "") {
        ToolTip "剪贴板内容为空，请先复制内容"
        SetTimer () => ToolTip(), -2000
        return
    }

    if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
        DllCall("EmptyClipboard")
        DllCall("CloseClipboard")
    }

    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"

    try {
        FileAppend targetText, tempFile, "UTF-8"
        SetClipboardFile(tempFile)
        Send "^v"

        SetTimer () => (
            FileExist(tempFile) ? FileDelete(tempFile) : "",
            (LastManualClipboard != "") ? (A_Clipboard := LastManualClipboard) : ""
        ), -10000

        SetTimer () => ToolTip(), -2000
    } catch Error as e {
        ToolTip "操作失败: " e.Message
        SetTimer () => ToolTip(), -2000
    }
}

+v:: ShowHistoryMenu()

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

SetClipboardFile(filePath) {
    static DROPFILES_SIZE := 20
    pathLen := StrLen(filePath)
    buf := Buffer(DROPFILES_SIZE + (pathLen + 2) * 2, 0)
    NumPut("UInt", DROPFILES_SIZE, buf, 0)
    NumPut("UInt", 1, buf, 16)
    StrPut(filePath, buf.Ptr + DROPFILES_SIZE, "UTF-16")

    if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
        DllCall("EmptyClipboard")
        hMem := DllCall("GlobalAlloc", "UInt", 0x42, "Ptr", buf.Size, "Ptr")
        pMem := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
        DllCall("RtlMoveMemory", "Ptr", pMem, "Ptr", buf.Ptr, "Ptr", buf.Size)
        DllCall("GlobalUnlock", "Ptr", hMem)
        DllCall("SetClipboardData", "UInt", 0xF, "Ptr", hMem)
        DllCall("CloseClipboard")
    }
}

HandleHistoryUpdate(DataType) {
    global ClipboardHistory, MaxHistory, LastManualClipboard
    if (DataType = 1) {
        text := A_Clipboard
        if InStr(text, A_Temp "\ClipTemp_")
            return

        LastManualClipboard := text

        for index, value in ClipboardHistory {
            if (value == text) {
                ClipboardHistory.RemoveAt(index)
                break
            }
        }
        ClipboardHistory.InsertAt(1, text)

        if (ClipboardHistory.Length > MaxHistory)
            ClipboardHistory.Pop()
    }
}

ShowHistoryMenu(isReturning := false) {
    global ClipboardHistory, MenuPosX, MenuPosY
    if (ClipboardHistory.Length = 0) {
        ToolTip "剪贴板历史为空"
        SetTimer () => ToolTip(), -1500
        return
    }

    if (!isReturning) {
        MouseGetPos(&MenuPosX, &MenuPosY)
    }

    HistoryMenu := Menu()
    for index, content in ClipboardHistory {
        display := StrReplace(SubStr(content, 1, 50), "`n", " ")
        if (StrLen(content) > 50)
            display .= "..."
        HistoryMenu.Add(index ". " display, ActionPickerHandler)
    }

    HistoryMenu.Show(MenuPosX, MenuPosY)
}

ActionPickerHandler(ItemName, ItemPos, MyMenu) {
    global SelectedIndex := ItemPos
    global SelectedText := ClipboardHistory[ItemPos]
    global MenuPosX, MenuPosY

    ActionMenu := Menu()
    ActionMenu.Add("📄 粘贴为 .txt 文件", (*) => PasteAsFile(SelectedText))
    ActionMenu.Add("🔍 预览全文", (*) => ShowPreviewGui(SelectedText))
    ActionMenu.Add("❌ 从历史中删除", DeleteHistoryItem)
    ActionMenu.Add()

    ActionMenu.Add("⬅️ 返回列表", (*) => SetTimer(() => ShowHistoryMenu(true), -10))

    ActionMenu.Show()
}

PasteAsFile(textContent) {
    global LastManualClipboard

    if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
        DllCall("EmptyClipboard")
        DllCall("CloseClipboard")
    }

    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"

    try {
        FileAppend textContent, tempFile, "UTF-8"
        SetClipboardFile(tempFile)
        Send "^v"

        SetTimer () => (
            FileExist(tempFile) ? FileDelete(tempFile) : "",
            (LastManualClipboard != "") ? (A_Clipboard := LastManualClipboard) : ""
        ), -10000
    } catch Error as e {
        ToolTip "写入失败: " e.Message
        SetTimer () => ToolTip(), -2000
    }
}

ShowPreviewGui(text) {
    PreviewGui := Gui("+AlwaysOnTop +Resize", "内容预览")
    PreviewGui.SetFont("s10", "Microsoft YaHei")

    EditCtrl := PreviewGui.Add("Edit", "ReadOnly VScroll Wrap w600 h400", text)

    BtnClose := PreviewGui.Add("Button", "Default w80", "关闭")
    BtnClose.OnEvent("Click", (*) => PreviewGui.Destroy())

    PreviewGui.OnEvent("Size", (guiObj, windowMinMax, width, height) => (
        EditCtrl.Move(10, 10, width - 20, height - 60),
        BtnClose.Move(width - 100, height - 40)
    ))

    PreviewGui.OnEvent("Escape", (*) => PreviewGui.Destroy())

    PreviewGui.Show()
}

DeleteHistoryItem(*) {
    global ClipboardHistory, SelectedIndex
    if (SelectedIndex <= ClipboardHistory.Length) {
        ClipboardHistory.RemoveAt(SelectedIndex)
        SetTimer () => ToolTip(), -1000
    }
}
