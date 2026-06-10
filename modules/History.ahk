#Requires AutoHotkey v2.0

LoadHistory() {
    global ClipboardHistory, MaxHistory, HistoryFile

    if (MaxHistory = 0) {
        ClipboardHistory := []
        return
    }

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

        CryptBuffer(buf)

        try {
            line := StrGet(buf, "UTF-8")
            pos1 := InStr(line, " | ")

            if (pos1 > 0) {
                timeStr := SubStr(line, 1, pos1 - 1)
                rest := SubStr(line, pos1 + 3)
                pos2 := InStr(rest, " | ")

                if (pos2 > 0) {
                    sourceStr := SubStr(rest, 1, pos2 - 1)
                    textStr := SubStr(rest, pos2 + 3)
                }
                else {
                    sourceStr := "Unknown Source"
                    textStr := rest
                }
            }
            else {
                timeStr := ""
                sourceStr := "Unknown Source"
                textStr := line
            }

            item := Map()
            item["time"] := timeStr
            item["source"] := sourceStr
            item["text"] := textStr
            history.Push(item)
        }
        catch {
            try {
                text := StrGet(buf, "UTF-8")
                item := Map()
                item["time"] := ""
                item["source"] := "Legacy Entry"
                item["text"] := text
                history.Push(item)
            }
            catch {
                break
            }
        }
    }

    file.Close()

    trimmedCount := 0
    while (history.Length > MaxHistory) {
        history.Pop()
        trimmedCount++
    }

    if (trimmedCount > 0) {
        OutputDebug "LoadHistory: trimmed " trimmedCount " entries exceeding MaxHistory=" MaxHistory
    }

    ClipboardHistory := history
}

SaveHistory() {
    global ClipboardHistory, HistoryFile

    file := FileOpen(HistoryFile, "w")

    if !IsObject(file)
        return

    file.WriteInt(ClipboardHistory.Length)

    for item in ClipboardHistory {
        line := item["time"] " | " item["source"] " | " item["text"]
        buf := Buffer(StrPut(line, "UTF-8") - 1)
        StrPut(line, buf, "UTF-8")
        CryptBuffer(buf)
        file.WriteInt(buf.Size)
        file.RawWrite(buf, buf.Size)
    }

    file.Close()
}

AddToHistory(text, source := "Manual Copy") {
    global ClipboardHistory, MaxHistory, IgnoreNextClipChange

    if (IgnoreNextClipChange) {
        IgnoreNextClipChange := false
        return
    }

    if (text == "")
        return

    if (ClipboardHistory.Length > 0 && ClipboardHistory[1]["text"] == text)
        return

    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    historyItem := Map()
    historyItem["text"] := text
    historyItem["source"] := source
    historyItem["process"] := ""
    historyItem["time"] := timestamp

    ClipboardHistory.InsertAt(1, historyItem)
    while (ClipboardHistory.Length > MaxHistory)
        ClipboardHistory.Pop()

    SaveHistory()
}

HandleHistoryUpdate(DataType) {
    global ClipboardHistory, MaxHistory, LastManualClipboard, IgnoreNextClipChange

    if (IgnoreNextClipChange) {
        IgnoreNextClipChange := false
        return
    }

    if (DataType != 1)
        return

    text := A_Clipboard

    if InStr(text, A_Temp "\ClipTemp_")
        return

    LastManualClipboard := text

    if (MaxHistory = 0)
        return

    try {
        sourceTitle := WinGetTitle("A")
    }
    catch {
        sourceTitle := "Unknown Window"
    }

    try {
        sourceProcess := WinGetProcessName("A")
    }
    catch {
        sourceProcess := "Unknown Process"
    }

    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    historyItem := Map()
    historyItem["text"] := text
    historyItem["source"] := sourceTitle
    historyItem["process"] := sourceProcess
    historyItem["time"] := timestamp
    for index, item in ClipboardHistory {
        if (item["text"] == text) {
            ClipboardHistory.RemoveAt(index)
            break
        }
    }

    ClipboardHistory.InsertAt(1, historyItem)
    while (ClipboardHistory.Length > MaxHistory)
        ClipboardHistory.Pop()

    SaveHistory()
}

ShowHistoryMenu(isReturning := false) {
    global ClipboardHistory, MenuPosX, MenuPosY, MAX_VISIBLE_MENU, TargetWindow

    TargetWindow := WinExist("A")

    if (ClipboardHistory.Length = 0) {
        ToolTip "No manual copy history"
        SetTimer () => ToolTip(), -1500
        return
    }

    if (!isReturning)
        MouseGetPos(&MenuPosX, &MenuPosY)

    HistoryMenu := Menu()
    total := ClipboardHistory.Length
    displayCount := total > MAX_VISIBLE_MENU ? MAX_VISIBLE_MENU : total

    loop displayCount {
        index := A_Index
        item := ClipboardHistory[index]
        content := item["text"]
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
    global SelectedIndex, SelectedItem

    SelectedIndex := ItemPos
    SelectedItem := ClipboardHistory[ItemPos]

    ActionMenu := Menu()
    ActionMenu.Add("📄 Paste as File", (*) => PasteAsFile(SelectedItem))
    ActionMenu.Add("🔍 Preview Content", (*) => ShowPreviewGui(SelectedItem["text"]))
    ActionMenu.Add("❌ Delete from History", DeleteHistoryItem)
    ActionMenu.Add()
    ActionMenu.Add("⬅️ Back to List", (*) => SetTimer(() => ShowHistoryMenu(true), -10))
    ActionMenu.Show()
}

PasteAsFile(historyItem) {
    global LastManualClipboard

    textContent := historyItem["text"]

    if (IsImagePathsText(textContent)) {
        originalClipboard := A_Clipboard
        A_Clipboard := textContent
        tempPDFPath := ProcessImagePathsToPDF()
        A_Clipboard := originalClipboard

        if (tempPDFPath = "") {
            ToolTip "Failed to create PDF from image paths."
            SetTimer () => ToolTip(), -2000
            return
        }

        PasteFile(tempPDFPath, "pdf")
        return
    }

    if (IsFilePath(textContent) && FileExist(textContent)) {
        filePath := textContent
        fileType := GetFileType(filePath)

        if (fileType = "pdf") {
            DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) && DllCall("EmptyClipboard")
            DllCall("CloseClipboard")
            SetClipboardFile(filePath)
        }
        else {
            sourceInfo := "Copied from: " historyItem["source"] " (at " historyItem["time"] ")"
            fullContent := "; " sourceInfo "`n`n" FileRead(filePath, "UTF-8")
            tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
            FileAppend fullContent, tempFile, "UTF-8"
            SetClipboardFile(tempFile)
        }
    }
    else {
        sourceInfo := "Copied from: " historyItem["source"] " (at " historyItem["time"] ")"
        DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) && DllCall("EmptyClipboard")
        DllCall("CloseClipboard")
        fullContent := "; " sourceInfo "`n`n" textContent
        tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
        FileAppend fullContent, tempFile, "UTF-8"
        SetClipboardFile(tempFile)
    }

    if (TargetWindow && WinExist("ahk_id " TargetWindow))
        WinActivate("ahk_id " TargetWindow)
    else {
        if !WinExist("A") {
            ToolTip "No target window to paste into. Please click on the desired window and try again."
            SetTimer () => ToolTip(), -2000
            return
        }
        WinActivate("A")
    }

    Sleep 100
    Send "^v"

    ; Schedule temp file cleanup and clipboard restoration
    if (IsSet(tempFile) && InStr(tempFile, A_Temp "\ClipTemp_"))
        ScheduleFileDeletion(tempFile)

    if (IsSet(filePath) && IsSet(fileType) && fileType = "pdf")
        ScheduleFileDeletion(filePath)

    SetTimer () => (
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

; === Full History GUI ===

ShowFullHistoryGui(ItemName?, ItemPos?, MyMenu?) {
    global ClipboardHistory, FullHistoryGui, TargetWindow

    TargetWindow := WinExist("A")

    if (FullHistoryGui) {
        try {
            if WinExist("ahk_id " FullHistoryGui.Hwnd) {
                WinActivate("ahk_id " FullHistoryGui.Hwnd)
                _RefreshFullHistoryList()
                return
            }
        }
        catch {
            FullHistoryGui := ""
        }
    }

    FullHistoryGui := Gui("+Resize +AlwaysOnTop", "Clipboard History (Full)")
    FullHistoryGui.SetFont("s10", "Microsoft YaHei")
    FullHistoryGui.OnEvent("Close", (*) => (FullHistoryGui.Destroy(), FullHistoryGui := ""))
    FullHistoryGui.OnEvent("Escape", (*) => (FullHistoryGui.Destroy(), FullHistoryGui := ""))
    FullHistoryGui.OnEvent("Size", _ResizeFullHistoryGui)

    lv := FullHistoryGui.Add("ListView", "r20 w600 Checked Multi Grid", [
        "#",
        "Content (first 100 chars)"
    ])
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
        try {
            if (Type(item) = "Map" && item.Has("text"))
                content := item["text"]
            else
                content := String(item ?? "")
        }
        catch {
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

    guiObj.btnPaste.Move(10, height - 80)
    guiObj.btnClose.Move(120, height - 80)
    guiObj.chkSelectAll.Move(10, height - 40)
    guiObj.btnDeleteSelected.Move(120, height - 40)
}

_OnFullHistoryDoubleClick(lv, row) {
    if (row = 0)
        return

    selectedItem := ClipboardHistory[row]
    _PasteAsMultipleFiles([
        selectedItem
    ])
}

_OnFullHistoryContextMenu(lv, row, isRightClick, x, y) {
    if (row = 0)
        return

    selectedItem := ClipboardHistory[row]
    ContextMenu := Menu()
    ContextMenu.Add("📄 Paste as File", (*) => _PasteAsMultipleFiles([
        selectedItem
    ]))
    ContextMenu.Add("🔍 Preview", (*) => ShowPreviewGui(selectedItem["text"]))
    ContextMenu.Add("❌ Delete", (*) => _DeleteFromFullHistory(row))
    ContextMenu.Show(x, y)
}

_PasteSelectedFromFullHistory() {
    global FullHistoryGui, ClipboardHistory, TargetWindow

    lv := FullHistoryGui.ListView
    fileList := []
    row := 0

    while (row := lv.GetNext(row, "Checked"))
        fileList.Push(ClipboardHistory[row])

    if (fileList.Length = 0) {
        ToolTip "Please select at least one item"
        SetTimer () => ToolTip(), -1500
        return
    }

    if !WinExist("ahk_id " TargetWindow) {
        currentWin := WinExist("A")

        if (currentWin && currentWin != FullHistoryGui.Hwnd) {
            TargetWindow := currentWin
        }
        else {
            ToolTip "Target window closed.`nSwitch to desired window within 2 seconds..."
            SetTimer () => ToolTip(), -2500

            loop 20 {
                Sleep 100
                currentWin := WinExist("A")

                if (currentWin && currentWin != FullHistoryGui.Hwnd) {
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

    state := WinGetMinMax("ahk_id " TargetWindow)

    if (state = -1)
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
    global TargetWindow, LastManualClipboard

    if (Type(textContent) = "Map")
        textToPaste := HasProp(textContent, "text") ? textContent["text"] : ""
    else
        textToPaste := textContent

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
    }
    else {
        textToPaste := textContent
        sourceInfo := ""

        for item in ClipboardHistory {
            if (item["text"] = textContent) {
                sourceInfo := "Copied from: " item["source"] " (at " item["time"] ")"
                break
            }
        }

        if (sourceInfo = "")
            sourceInfo := "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
    }

    fullContent := "; " sourceInfo "`n`n" textToPaste
    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend fullContent, tempFile, "UTF-8"
    SetClipboardFile(tempFile)

    if (activate) {
        if !WinExist("ahk_id " TargetWindow) {
            ToolTip "Target window not found, paste cancelled."
            SetTimer () => ToolTip(), -1500
            return
        }

        state := WinGetMinMax("ahk_id " TargetWindow)

        if (state = -1)
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
    }
    else {
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

    ; Delete from end to start to preserve indices
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

_PasteAsMultipleFiles(textArray) {
    global TargetWindow

    tempFiles := []

    for item in textArray {
        if (Type(item) = "Map") {
            textToWrite := HasProp(item, "text") ? item["text"] : ""
            sourceInfo := "Copied from: "
                . (HasProp(item, "source") ? item["source"] : "Unknown Source")
                . " (at "
                . (HasProp(item, "time") ? item["time"] : FormatTime(, "yyyy-MM-dd HH:mm:ss"))
                . ")"
        }
        else {
            textToWrite := item
            sourceInfo := "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        }

        fullContent := "; " sourceInfo "`n`n" textToWrite
        tempFile := A_Temp "\ClipTemp_" A_TickCount "_" A_Index ".txt"
        FileAppend fullContent, tempFile, "UTF-8"
        tempFiles.Push(tempFile)
    }

    SetClipboardFiles(tempFiles)

    if (TargetWindow && WinExist("ahk_id " TargetWindow))
        WinActivate("ahk_id " TargetWindow)
    else {
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

_UpdateSelectAllCheckbox() {
    global FullHistoryGui

    lv := FullHistoryGui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0

    while (row := lv.GetNext(row, "Checked"))
        checked++

    FullHistoryGui.chkSelectAll.Value := (checked = total) ? 1 : 0
}

_OnItemCheck(lv, row, checked) {
    _UpdateSelectAllCheckbox()
}

GetSourceInfo() {
    try {
        title := WinGetTitle("A")

        if (title = "")
            title := "Unknown Window"
    }
    catch {
        title := "Unknown Window"
    }

    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    return "Source: " title " | Time: " timestamp
}
