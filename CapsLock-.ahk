#Requires AutoHotkey v2.0
#SingleInstance Force

global LastManualClipboard := ""
global ClipboardHistory := []
global MaxHistory := 10000
global MAX_VISIBLE_MENU := 15
global FullHistoryGui := ""
global MenuPosX := 0
global MenuPosY := 0
global HistoryFile := A_ScriptDir "\ClipHistory.bin"
global TargetWindow := 0

LoadHistory()

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

a:: Send "{Backspace}"
d:: Send "{Delete}"
+a:: Send "^{Backspace}"
+d:: Send "^{Delete}"
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
        ToolTip "Clipboard is empty, please copy content first"
        SetTimer () => ToolTip(), -2000
        return
    }

    if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
        DllCall("EmptyClipboard")
        DllCall("CloseClipboard")
    }

    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"

    FileAppend targetText, tempFile, "UTF-8"
    SetClipboardFile(tempFile)
    Send "^v"

    SetTimer () => (
        FileExist(tempFile) ? FileDelete(tempFile) : "",
        (LastManualClipboard != "") ? (A_Clipboard := LastManualClipboard) : ""
    ), -10000

    SetTimer () => ToolTip(), -2000
}

+v:: ShowHistoryMenu()

#HotIf

; =========================== Method =========================== ;
AdjustOpacity(step) {
    hwnd := WinExist("A")
    currentTrans := WinGetTransparent(hwnd)

    if (currentTrans = "")
        currentTrans := 255

    newTrans := Clamp(currentTrans + step, 20, 255)
    WinSetTransparent(newTrans, hwnd)
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

        SaveHistory()

    }
}

ShowHistoryMenu(isReturning := false) {
    TargetWindow := WinExist("A")
    global ClipboardHistory, MenuPosX, MenuPosY, MAX_VISIBLE_MENU
    if (ClipboardHistory.Length = 0) {
        ToolTip "No manual copy history"
        SetTimer () => ToolTip(), -1500
        return
    }

    if (!isReturning) {
        MouseGetPos(&MenuPosX, &MenuPosY)
    }

    HistoryMenu := Menu()
    total := ClipboardHistory.Length

    displayCount := total > MAX_VISIBLE_MENU ? MAX_VISIBLE_MENU : total
    loop displayCount {
        index := A_Index
        content := ClipboardHistory[index]
        display := StrReplace(SubStr(content, 1, 50), "`n", " ")
        if (StrLen(content) > 50)
            display .= "..."
        HistoryMenu.Add(index ". " display, ActionPickerHandler)
    }

    if (total > MAX_VISIBLE_MENU) {
        HistoryMenu.Add()
        HistoryMenu.Add("📋 View full history (" total " items)...", ShowFullHistoryGui)
    }

    HistoryMenu.Show(MenuPosX, MenuPosY)
}

ActionPickerHandler(ItemName, ItemPos, MyMenu) {
    global SelectedIndex := ItemPos
    global SelectedText := ClipboardHistory[ItemPos]
    global MenuPosX, MenuPosY

    ActionMenu := Menu()
    ActionMenu.Add("📄 Paste as .txt file", (*) => PasteAsFile(SelectedText))
    ActionMenu.Add("🔍 Preview Content", (*) => ShowPreviewGui(SelectedText))
    ActionMenu.Add("❌ Delete from History", DeleteHistoryItem)
    ActionMenu.Add()

    ActionMenu.Add("⬅️ Back to List", (*) => SetTimer(() => ShowHistoryMenu(true), -10))

    ActionMenu.Show()
}

PasteAsFile(textContent) {
    global LastManualClipboard

    if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
        DllCall("EmptyClipboard")
        DllCall("CloseClipboard")
    }

    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"

    FileAppend textContent, tempFile, "UTF-8"
    SetClipboardFile(tempFile)

    if TargetWindow && WinExist("ahk_id " TargetWindow) {
        WinActivate("ahk_id " TargetWindow)
    } else {
        if !WinExist("A") {
            ToolTip "No target window to paste into. Please click on the desired window and try again."
            SetTimer () => ToolTip(), -2000
            return
        }
        WinActivate("A")
    }
    Sleep 100

    Send "^v"
    SetTimer () => (
        FileExist(tempFile) ? FileDelete(tempFile) : "",
        (LastManualClipboard != "") ? (A_Clipboard := LastManualClipboard) : ""
    ), -10000
}

ShowPreviewGui(text) {
    PreviewGui := Gui("+AlwaysOnTop +Resize", "Preview Content")
    PreviewGui.SetFont("s10", "Microsoft YaHei")

    EditCtrl := PreviewGui.Add("Edit", "ReadOnly VScroll Wrap w600 h400", text)

    BtnClose := PreviewGui.Add("Button", "Default w80", "Close")
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
        SaveHistory()
        SetTimer () => ToolTip(), -1000
    }
}

LoadHistory() {
    global ClipboardHistory, MaxHistory, HistoryFile
    if !FileExist(HistoryFile)
        return

    file := FileOpen(HistoryFile, "r")
    if !IsObject(file)
        return

    arrayLen := file.ReadInt()
    if (arrayLen = "" || arrayLen < 0) {
        file.Close()
        return
    }

    history := []
    loop arrayLen {
        strLenBytes := file.ReadInt()
        if (strLenBytes = "" || strLenBytes <= 0)
            break

        buf := Buffer(strLenBytes)
        if (file.RawRead(buf, strLenBytes) != strLenBytes)
            break

        text := StrGet(buf, "UTF-8")
        history.Push(text)
    }
    file.Close()

    while history.Length > MaxHistory
        history.Pop()
    ClipboardHistory := history
}

SaveHistory() {
    global ClipboardHistory, HistoryFile
    file := FileOpen(HistoryFile, "w")
    if !IsObject(file)
        return

    file.WriteInt(ClipboardHistory.Length)

    for text in ClipboardHistory {
        buf := Buffer(StrPut(text, "UTF-8") - 1)
        StrPut(text, buf, "UTF-8")

        file.WriteInt(buf.Size)

        file.RawWrite(buf, buf.Size)
    }
    file.Close()
}

ShowFullHistoryGui(ItemName, ItemPos, MyMenu) {
    global ClipboardHistory, FullHistoryGui
    TargetWindow := WinExist("A")

    if (FullHistoryGui) {
        try {
            if WinExist("ahk_id " FullHistoryGui.Hwnd) {
                WinActivate("ahk_id " FullHistoryGui.Hwnd)
                _RefreshFullHistoryList()
                return
            }
        } catch {
            FullHistoryGui := ""
        }
    }

    FullHistoryGui := Gui("+Resize +AlwaysOnTop", "Clipboard History (Full)")
    FullHistoryGui.SetFont("s10", "Microsoft YaHei")
    FullHistoryGui.OnEvent("Close", (*) => (FullHistoryGui.Destroy(), FullHistoryGui := ""))
    FullHistoryGui.OnEvent("Escape", (*) => (FullHistoryGui.Destroy(), FullHistoryGui := ""))
    FullHistoryGui.OnEvent("Size", _ResizeFullHistoryGui)

    lv := FullHistoryGui.Add("ListView", "r20 w600 Checked Multi Grid", ["#", "Content (first 100 chars)"])
    lv.OnEvent("DoubleClick", _OnFullHistoryDoubleClick)
    lv.OnEvent("ContextMenu", _OnFullHistoryContextMenu)
    lv.OnEvent("ItemCheck", _OnItemCheck)
    FullHistoryGui.ListView := lv

    btnPaste := FullHistoryGui.Add("Button", "Default", "Paste as File")
    btnPaste.OnEvent("Click", (*) => _PasteSelectedFromFullHistory())
    FullHistoryGui.btnPaste := btnPaste

    btnClose := FullHistoryGui.Add("Button", "x+10 yp", "Close")
    btnClose.OnEvent("Click", (*) => FullHistoryGui.Destroy())
    FullHistoryGui.btnClose := btnClose

    chkSelectAll := FullHistoryGui.Add("CheckBox", "x10 y+20", "Select All")
    chkSelectAll.OnEvent("Click", _OnSelectAllClicked)
    FullHistoryGui.chkSelectAll := chkSelectAll

    btnDeleteSelected := FullHistoryGui.Add("Button", "x+10 yp", "Delete Selected")
    btnDeleteSelected.OnEvent("Click", _OnDeleteSelected)
    FullHistoryGui.btnDeleteSelected := btnDeleteSelected

    _RefreshFullHistoryList()
    FullHistoryGui.Show()
}

_RefreshFullHistoryList() {
    global ClipboardHistory, FullHistoryGui
    lv := FullHistoryGui.ListView
    lv.Delete()
    for idx, content in ClipboardHistory {
        display := StrReplace(SubStr(content, 1, 100), "`n", " ")
        if (StrLen(content) > 100)
            display .= "..."
        lv.Add(, idx, display)
    }
    lv.ModifyCol(1, "AutoHdr")
    lv.ModifyCol(2, "AutoHdr")
    FullHistoryGui.chkSelectAll.Value := 0
}

_ResizeFullHistoryGui(guiObj, windowMinMax, width, height) {
    lv := guiObj.ListView
    lv.Move(10, 10, width - 20, height - 100)

    btnPaste := guiObj.btnPaste
    btnClose := guiObj.btnClose
    chkSelectAll := guiObj.chkSelectAll
    btnDeleteSelected := guiObj.btnDeleteSelected

    btnPaste.Move(10, height - 80)
    btnClose.Move(120, height - 80)

    chkSelectAll.Move(10, height - 40)
    btnDeleteSelected.Move(120, height - 40)
}

_OnFullHistoryDoubleClick(lv, row) {
    if (row = 0)
        return
    selectedText := ClipboardHistory[row]
    _PasteAsMultipleFiles([selectedText])
}

_OnFullHistoryContextMenu(lv, row, isRightClick, x, y) {
    if (row = 0)
        return
    selectedText := ClipboardHistory[row]

    ContextMenu := Menu()
    ContextMenu.Add("📄 Paste as File", (*) => _PasteAsMultipleFiles([selectedText]))
    ContextMenu.Add("🔍 Preview", (*) => ShowPreviewGui(selectedText))
    ContextMenu.Add("❌ Delete", (*) => _DeleteFromFullHistory(row))
    ContextMenu.Show(x, y)
}

_PasteSelectedFromFullHistory() {
    global FullHistoryGui, ClipboardHistory, TargetWindow
    lv := FullHistoryGui.ListView
    fileList := []
    row := 0
    while (row := lv.GetNext(row, "Checked")) {
        fileList.Push(ClipboardHistory[row])
    }
    if (fileList.Length = 0) {
        ToolTip "Please select at least one item"
        SetTimer () => ToolTip(), -1500
        return
    }

    if !WinExist("ahk_id " TargetWindow) {
        currentWin := WinExist("A")
        if currentWin && currentWin != FullHistoryGui.Hwnd {
            TargetWindow := currentWin
        } else {
            ToolTip "Target window closed.`nSwitch to desired window within 2 seconds..."
            SetTimer () => ToolTip(), -2500
            loop 20 {
                Sleep 100
                currentWin := WinExist("A")
                if currentWin && currentWin != FullHistoryGui.Hwnd {
                    TargetWindow := currentWin
                    break
                }
            }
            if !TargetWindow {
                ToolTip "No new window detected, operation cancelled"
                SetTimer () => ToolTip(), -2000
                return
            }
        }
    }

    local state := ""
    WinGetMinMax("ahk_id " TargetWindow, state)
    if state == -1
        WinRestore("ahk_id " TargetWindow)
    WinActivate("ahk_id " TargetWindow)

    if !WinWaitActive("ahk_id " TargetWindow, , 1) {
        ToolTip "Cannot activate target window, please click it manually"
        SetTimer () => ToolTip(), -2000
        return
    }

    Sleep 100

    for text in fileList {
        _PasteSingleFile(text, false)
        Sleep 200
    }

    ToolTip "Paste completed"
    SetTimer () => ToolTip(), -1500
}

_PasteSingleFile(textContent, activate := true) {
    global TargetWindow
    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend textContent, tempFile, "UTF-8"
    SetClipboardFile(tempFile)

    if activate {
        if !WinExist("ahk_id " TargetWindow) {
            ToolTip "Target window not found, paste cancelled."
            SetTimer () => ToolTip(), -1500
            return
        }
        local state := ""
        WinGetMinMax("ahk_id " TargetWindow, state)
        if state = -1
            WinRestore("ahk_id " TargetWindow)

        WinActivate("ahk_id " TargetWindow)
        if !WinWaitActive("ahk_id " TargetWindow, , 1) {
            ToolTip "Cannot activate target window, please try manually."
            SetTimer () => ToolTip(), -2000
            return
        }
    }

    ToolTip "Pasting: " SubStr(textContent, 1, 40) "..."
    Send "^v"
    Sleep 50

    SetTimer () => (FileExist(tempFile) ? FileDelete(tempFile) : "", ToolTip()), -10000
}

_OnSelectAllClicked(chk, info) {
    lv := chk.Gui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0
    while (row := lv.GetNext(row, "Checked"))
        checked++
    if (checked = total) {
        loop total
            lv.Modify(A_Index, "-Check")
        chk.Value := 0
    } else {
        loop total
            lv.Modify(A_Index, "Check")
        chk.Value := 1
    }
}

_OnDeleteSelected(*) {
    global ClipboardHistory, FullHistoryGui
    lv := FullHistoryGui.ListView
    rowsToDelete := []
    row := 0
    while (row := lv.GetNext(row, "Checked"))
        rowsToDelete.Push(row)
    if (rowsToDelete.Length = 0) {
        ToolTip "No checked items"
        SetTimer () => ToolTip(), -1500
        return
    }

    loop rowsToDelete.Length {
        idx := rowsToDelete[rowsToDelete.Length - A_Index + 1]
        ClipboardHistory.RemoveAt(idx)
    }
    SaveHistory()
    _RefreshFullHistoryList()
}

_DeleteFromFullHistory(index) {
    global ClipboardHistory, FullHistoryGui
    if (index <= ClipboardHistory.Length) {
        ClipboardHistory.RemoveAt(index)
        SaveHistory()
        _RefreshFullHistoryList()
    }
}

SetClipboardFiles(fileArray) {
    static DROPFILES_SIZE := 20

    totalBytes := DROPFILES_SIZE
    for path in fileArray {
        totalBytes += StrPut(path, "UTF-16") * 2
    }
    totalBytes += 2

    buf := Buffer(totalBytes, 0)

    NumPut("UInt", DROPFILES_SIZE, buf, 0)
    NumPut("UInt", 0, buf, 4)
    NumPut("UInt", 0, buf, 8)
    NumPut("UInt", 0, buf, 12)
    NumPut("UInt", 1, buf, 16)

    offset := DROPFILES_SIZE
    for path in fileArray {
        StrPut(path, buf.Ptr + offset, "UTF-16")
        offset += StrPut(path, "UTF-16") * 2
    }

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

_PasteAsMultipleFiles(textArray) {
    global TargetWindow
    tempFiles := []
    for text in textArray {
        tempFile := A_Temp "\ClipTemp_" A_TickCount "_" A_Index ".txt"
        FileAppend text, tempFile, "UTF-8"
        tempFiles.Push(tempFile)
    }

    SetClipboardFiles(tempFiles)

    if TargetWindow && WinExist("ahk_id " TargetWindow) {
        WinActivate("ahk_id " TargetWindow)
    } else {
        if !WinExist("A") {
            ToolTip "No target window to paste into."
            SetTimer () => ToolTip(), -1500
            return
        }
        WinActivate("A")
    }
    Sleep 100
    Send "^v"

    SetTimer (_DeleteTempFiles.Bind(tempFiles)), -10000
}

_DeleteTempFiles(files) {
    for f in files
        FileExist(f) ? FileDelete(f) : ""
}

_UpdateSelectAllCheckbox() {
    global FullHistoryGui
    lv := FullHistoryGui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0
    while (row := lv.GetNext(row, "Checked"))
        checked++
    chkSelectAll := FullHistoryGui.chkSelectAll
    chkSelectAll.Value := (checked = total) ? 1 : 0
}

_OnItemCheck(lv, row, checked) {
    _UpdateSelectAllCheckbox()
}
