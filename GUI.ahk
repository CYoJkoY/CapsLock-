; =========================== GUI.ahk ===========================
; GUI 界面管理模块：预览窗口、历史记录完整窗口

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

ShowFullHistoryGui(ItemName, ItemPos, MyMenu) {
    global ClipboardHistory, FullHistoryGui, TargetWindow

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
    for idx, item in ClipboardHistory {
        local display, content
        try {
            if (Type(item) = "Map" and item.Has("text")) {
                content := item["text"]
            } else {
                content := String(item ?? "")
            }
        } catch as err {
            content := "[Invalid History Entry]"
        }

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
    selectedItem := ClipboardHistory[row]
    _PasteAsMultipleFiles([selectedItem])
}

_OnFullHistoryContextMenu(lv, row, isRightClick, x, y) {
    if (row = 0)
        return
    selectedItem := ClipboardHistory[row]

    ContextMenu := Menu()
    ContextMenu.Add("📄 Paste as File", (*) => _PasteAsMultipleFiles([selectedItem]))
    ContextMenu.Add("🔍 Preview", (*) => ShowPreviewGui(selectedItem["text"]))
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

    for item in fileList {
        _PasteSingleFile(item["text"], false)
        Sleep 200
    }

    ToolTip "Paste completed"
    SetTimer () => ToolTip(), -1500
}

_PasteSingleFile(textContent, activate := true) {
    global TargetWindow
    global LastManualClipboard

    if (Type(textContent) = "Map") {
        textToPaste := HasProp(textContent, "text") ? textContent["text"] : ""
    } else {
        textToPaste := textContent
    }

    if (IsImagePathsText(textToPaste)) {
        originalClipboard := A_Clipboard
        A_Clipboard := textToPaste

        tempPDFPath := ProcessImagePathsToPDF()

        A_Clipboard := originalClipboard

        if (tempPDFPath = "") {
            ToolTip "Failed to create PDF from image paths in Full History."
            SetTimer () => ToolTip(), -2000
            return
        }

        PasteFile(tempPDFPath, "pdf")
        return
    }

    if (Type(textContent) = "Map") {
        textToPaste := HasProp(textContent, "text") ? textContent["text"] : ""
        sourceInfo := "Copied from: "
            . (HasProp(textContent, "source") ? textContent["source"] : "Unknown Source")
            . " (at "
            . (HasProp(textContent, "time") ? textContent["time"] : FormatTime(, "yyyy-MM-dd HH:mm:ss"))
            . ")"
    } else {
        textToPaste := textContent
        sourceInfo := ""
        for item in ClipboardHistory {
            if (item["text"] = textContent) {
                sourceInfo := "Copied from: " item["source"] " (at " item["time"] ")"
                break
            }
        }

        if (sourceInfo = "") {
            sourceInfo := "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        }
    }

    fullContent := "; " sourceInfo "`n`n" textToPaste

    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend fullContent, tempFile, "UTF-8"
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

    ToolTip "Pasting: " SubStr(textToPaste, 1, 40) "..."
    Send "^v"
    Sleep 50

    ScheduleFileDeletion(tempFile)
    SetTimer () => ToolTip(), -10000
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
    for item in textArray {
        local textToWrite, sourceInfo, fullContent
        if (Type(item) = "Map") {
            textToWrite := HasProp(item, "text") ? item["text"] : ""
            sourceInfo := "Copied from: "
                . (HasProp(item, "source") ? item["source"] : "Unknown Source")
                . " (at "
                . (HasProp(item, "time") ? item["time"] : FormatTime(, "yyyy-MM-dd HH:mm:ss"))
                . ")"
        } else {
            textToWrite := item
            sourceInfo := "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        }
        fullContent := "; " sourceInfo "`n`n" textToWrite
        tempFile := A_Temp "\ClipTemp_" A_TickCount "_" A_Index ".txt"
        FileAppend fullContent, tempFile, "UTF-8"
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

    for f in tempFiles
        ScheduleFileDeletion(f)
}
