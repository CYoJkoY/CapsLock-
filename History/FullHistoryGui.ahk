#Requires AutoHotkey v2.0

ShowFullHistoryGui(ItemName?, ItemPos?, MyMenu?) {
    AppState.TargetWindow := WinExist("A")
    AppState.MAX_FULL_HISTORY_DISPLAY := 50

    if IsObject(AppState.FullHistoryGui) {
        try {
            if WinExist("ahk_id " AppState.FullHistoryGui.Hwnd) {
                WinActivate("ahk_id " AppState.FullHistoryGui.Hwnd)
                RefreshFullHistoryList()
                return
            }
        } catch {
            AppState.FullHistoryGui := ""
        }
    }

    myGui := Gui("+Resize +AlwaysOnTop +MinSize680x500", Lang("GUI_FULL_TITLE"))
    ThemeHelper.StyleGui(myGui)
    myGui.OnEvent("Close", (*) => CloseFullHistoryGui(myGui))
    myGui.OnEvent("Escape", (*) => CloseFullHistoryGui(myGui))
    myGui.OnEvent("Size", ResizeFullHistoryGui)

    margin := 16
    titleAreaH := 56
    separatorH := 2
    searchAreaH := 34
    gap := 10

    titleY := margin
    sep1Y := titleY + titleAreaH
    searchY := sep1Y + separatorH + gap
    lvY := searchY + searchAreaH + gap

    ThemeHelper.AddTitle(myGui, "📋 " Lang("GUI_FULL_TITLE"), 640)
    ThemeHelper.AddSubtitle(
        myGui,
        Lang("GUI_FULL_SUBTITLE", "", Lang("GUI_FULL_SUBTITLE_0")),
        640
    )
    ThemeHelper.AddSeparator(myGui, 640)

    myGui.SetFont("s10 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
    searchIcon := myGui.Add("Text", "x" margin " y" searchY, "🔍")
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
    searchBox := myGui.Add(
        "Edit",
        "x" (margin + 22) " y" (searchY - 2) " w604 " ThemeHelper.GetEditOptions("r1")
    )
    searchBox.OnEvent("Change", (*) => (
        AppState.MAX_FULL_HISTORY_DISPLAY := 50,
        RefreshFullHistoryList()
    ))
    myGui.SearchBox := searchBox
    myGui.SearchIcon := searchIcon

    lv := myGui.Add(
        "ListView",
        "x" margin " y" lvY " r18 w640 Checked Multi " ThemeHelper.GetLVOptions(),
        ["#", "Content", "Time"]
    )
    lv.ModifyCol(1, "Integer")
    lv.ModifyCol(1, 50)
    lv.ModifyCol(3, 80)
    lv.OnEvent("DoubleClick", OnFullHistoryDoubleClick)
    lv.OnEvent("ContextMenu", OnFullHistoryContextMenu)
    lv.OnEvent("ItemCheck", OnItemCheck)
    myGui.ListView := lv
    ThemeHelper.StyleListView(lv)

    ThemeHelper.AddSeparator(myGui, 640)

    btnPaste := ThemeHelper.AddButton(myGui, "Default w120", "📄 " Lang("GUI_FULL_PASTE_FILE"), "primary")
    btnPaste.OnEvent("Click", (*) => PasteSelectedFromFullHistory())
    myGui.btnPaste := btnPaste

    btnPasteText := ThemeHelper.AddButton(myGui, "x+8 yp w120", "📝 " Lang("GUI_FULL_PASTE_TEXT"))
    btnPasteText.OnEvent("Click", (*) => PasteSelectedFromFullHistoryText())
    myGui.btnPasteText := btnPasteText

    btnClose := ThemeHelper.AddButton(myGui, "x+8 yp w80", Lang("GUI_FULL_CLOSE"))
    btnClose.OnEvent("Click", (*) => CloseFullHistoryGui(myGui))
    myGui.btnClose := btnClose

    chkSelectAll := myGui.Add(
        "CheckBox",
        "x16 y+16 " ThemeHelper.GetCheckBoxOptions(),
        Lang("GUI_FULL_SELECT_ALL")
    )
    chkSelectAll.OnEvent("Click", OnSelectAllClicked)
    myGui.chkSelectAll := chkSelectAll

    btnDelete := ThemeHelper.AddButton(myGui, "x+12 yp w100", "🗑️ " Lang("GUI_FULL_DELETE_SELECTED"), "danger")
    btnDelete.OnEvent("Click", OnDeleteSelected)
    myGui.btnDeleteSelected := btnDelete

    btnLoadMore := ThemeHelper.AddButton(myGui, "x+12 yp w100", "⬇️ " Lang("GUI_FULL_LOAD_MORE", "", "Load More"))
    btnLoadMore.OnEvent("Click", OnLoadMoreClicked)
    myGui.btnLoadMore := btnLoadMore

    myGui.SetFont("s8 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
    statusBar := myGui.Add(
        "Text",
        "x16 y+12 w640",
        " " Lang("GUI_FULL_STATUS", "", "Ready") " | "
            . Lang("GUI_FULL_TIP", "", "Tip: Use checkboxes to select multiple items")
    )
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
    myGui.StatusBar := statusBar

    AppState.FullHistoryGui := myGui
    myGui.Show("w680 h580")
    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
    RefreshFullHistoryList()
}

CloseFullHistoryGui(myGui) {
    AppState.MAX_FULL_HISTORY_DISPLAY := 50
    try myGui.Destroy()
    AppState.FullHistoryGui := ""
    AppState.TargetWindow := 0
}

OnLoadMoreClicked(btn, info) {
    AppState.MAX_FULL_HISTORY_DISPLAY += 50
    RefreshFullHistoryList(true)
}

RefreshFullHistoryList(isIncremental := false) {
    myGui := AppState.FullHistoryGui
    if !IsObject(myGui)
        return

    lv := myGui.ListView
    filter := Trim(myGui.SearchBox.Text)
    maxDisplay := AppState.MAX_FULL_HISTORY_DISPLAY

    needRebuild := !isIncremental
        || !myGui.HasProp("cachedMatching")
        || (myGui.HasProp("lastFilter") && myGui.lastFilter != filter)

    if needRebuild {
        matching := []

        ; Pre-calculate filter once, outside the loop
        hasFilter := filter != ""

        for i, item in AppState.History {
            rawText := item["text"]
            ; Cache the raw text for filter comparison
            display := RegExReplace(SubStr(rawText, 1, 80), "[\r\n\t\v\f]+", " ")
            if StrLen(rawText) > 80
                display .= "…"

            timeShort := SubStr(item["time"], 12, 5)

            if hasFilter && !InStr(display, filter) && !InStr(rawText, filter)
                continue

            matching.Push({ index: i, display: display, time: timeShort })
        }

        myGui.cachedMatching := matching
        myGui.lastFilter := filter
        myGui.displayedCount := 0

        SendMessage(0x000B, 0, 0, lv.Hwnd)
        lv.Delete()
    } else {
        SendMessage(0x000B, 0, 0, lv.Hwnd)
    }

    matching := myGui.cachedMatching
    totalMatching := matching.Length
    prevDisplayed := myGui.HasProp("displayedCount") ? myGui.displayedCount : 0

    startIdx := prevDisplayed + 1
    endIdx := Min(maxDisplay, totalMatching)

    if startIdx <= endIdx {
        Loop endIdx - startIdx + 1 {
            entry := matching[startIdx + A_Index - 1]
            lv.Add(, entry.index, entry.display, entry.time)
        }
        myGui.displayedCount := endIdx
    }

    SendMessage(0x000B, 1, 0, lv.Hwnd)
    DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", 1)

    if needRebuild {
        lv.ModifyCol(2, "AutoHdr")
        if lv.GetCount() > 0
            SendMessage(0x1017, 0, 0, lv.Hwnd)
    }

    if myGui.HasProp("StatusBar") {
        displayCount := Min(maxDisplay, totalMatching)
        statusKey := filter ? "GUI_FULL_STATUSBAR_FILTERED" : "GUI_FULL_STATUSBAR"
        myGui.StatusBar.Text := lang(statusKey, , totalMatching, displayCount)
    }

    myGui.chkSelectAll.Value := 0
}

ResizeFullHistoryGui(guiObj, minmax, width, height) {
    if !IsObject(guiObj) || !IsObject(guiObj.ListView)
        return

    margin := 16
    titleAreaH := 56
    separatorH := 2
    searchAreaH := 34
    btnAreaH := 40
    toolAreaH := 36
    statusH := 24
    gap := 10

    searchY := margin + titleAreaH + separatorH + gap
    if guiObj.HasProp("SearchIcon")
        try guiObj.SearchIcon.Move(margin, searchY)
    if guiObj.HasProp("SearchBox")
        try guiObj.SearchBox.Move(margin + 22, searchY - 2, width - margin * 2 - 22)

    lvY := searchY + searchAreaH + gap
    lvH := height - lvY - btnAreaH - toolAreaH - statusH - gap * 3
    if lvH < 100
        lvH := 100
    guiObj.ListView.Move(margin, lvY, width - margin * 2, lvH)

    btnY := lvY + lvH + gap
    btnPaste := guiObj.btnPaste
    btnPasteText := guiObj.btnPasteText
    btnClose := guiObj.btnClose
    if IsObject(btnPaste) && IsObject(btnPasteText) && IsObject(btnClose) {
        btnPaste.GetPos(, , &w1)
        btnPasteText.GetPos(, , &w2)
        btnClose.GetPos(, , &w3)
        spacing := 8
        totalBtnWidth := w1 + w2 + w3 + spacing * 2
        startX := width - totalBtnWidth - margin
        btnPaste.Move(startX, btnY)
        btnPasteText.Move(startX + w1 + spacing, btnY)
        btnClose.Move(startX + w1 + spacing + w2 + spacing, btnY)
    }

    toolY := btnY + btnAreaH + gap
    chkSelectAll := guiObj.chkSelectAll
    btnDelete := guiObj.btnDeleteSelected
    btnLoadMore := guiObj.btnLoadMore
    if IsObject(chkSelectAll) && IsObject(btnDelete) && IsObject(btnLoadMore) {
        chkSelectAll.GetPos(, , &w4)
        btnDelete.GetPos(, , &w5)
        btnLoadMore.GetPos(, , &w6)
        spacing := 12
        totalWidth2 := w4 + w5 + w6 + spacing * 2
        startX2 := width - totalWidth2 - margin
        chkSelectAll.Move(startX2, toolY)
        btnDelete.Move(startX2 + w4 + spacing, toolY)
        btnLoadMore.Move(startX2 + w4 + spacing + w5 + spacing, toolY)
    }

    if guiObj.HasProp("StatusBar")
        guiObj.StatusBar.Move(margin, height - statusH - 4, width - margin * 2)
}
