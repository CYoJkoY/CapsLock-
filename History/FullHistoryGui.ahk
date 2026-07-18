#Requires AutoHotkey v2.0

ShowFullHistoryGui( ItemName?, ItemPos?, MyMenu? ) {
    AppState.TargetWindow := WinExist( "A" )
    if IsObject( AppState.FullHistoryGui ) {
        try {
            if WinExist( "ahk_id " AppState.FullHistoryGui.Hwnd ) {
                WinActivate( "ahk_id " AppState.FullHistoryGui.Hwnd )
                RefreshFullHistoryList()
                return
            }
        } catch {
            AppState.FullHistoryGui := ""
        }
    }

    myGui := Gui( "+Resize +AlwaysOnTop", Lang( "GUI_FULL_TITLE" ) )
    myGui.SetFont( "s10", "Microsoft YaHei" )
    myGui.OnEvent( "Close", ( * ) => ( myGui.Destroy(), AppState.FullHistoryGui := "" ) )
    myGui.OnEvent( "Escape", ( * ) => ( myGui.Destroy(), AppState.FullHistoryGui := "" ) )
    myGui.OnEvent( "Size", ResizeFullHistoryGui )

    searchBox := myGui.Add( "Edit", "w600", "" )
    searchBox.OnEvent( "Change", ( * ) => RefreshFullHistoryList() )
    myGui.SearchBox := searchBox

    lv := myGui.Add( "ListView", "r20 w600 Checked Multi Grid", [ "#", "Content (first 100 chars)" ] )
    lv.OnEvent( "DoubleClick", OnFullHistoryDoubleClick )
    lv.OnEvent( "ContextMenu", OnFullHistoryContextMenu )
    lv.OnEvent( "ItemCheck", OnItemCheck )
    myGui.ListView := lv

    btnPaste := myGui.Add( "Button", "Default", Lang( "GUI_FULL_PASTE_FILE" ) )
    btnPaste.OnEvent( "Click", ( * ) => PasteSelectedFromFullHistory() )
    myGui.btnPaste := btnPaste

    btnPasteText := myGui.Add( "Button", "x+10 yp", Lang( "GUI_FULL_PASTE_TEXT" ) )
    btnPasteText.OnEvent( "Click", ( * ) => PasteSelectedFromFullHistoryText() )
    myGui.btnPasteText := btnPasteText

    btnClose := myGui.Add( "Button", "x+10 yp", Lang( "GUI_FULL_CLOSE" ) )
    btnClose.OnEvent( "Click", ( * ) => myGui.Destroy() )
    myGui.btnClose := btnClose

    chkSelectAll := myGui.Add( "CheckBox", "x10 y+20", Lang( "GUI_FULL_SELECT_ALL" ) )
    chkSelectAll.OnEvent( "Click", OnSelectAllClicked )
    myGui.chkSelectAll := chkSelectAll

    btnDelete := myGui.Add( "Button", "x+10 yp", Lang( "GUI_FULL_DELETE_SELECTED" ) )
    btnDelete.OnEvent( "Click", OnDeleteSelected )
    myGui.btnDeleteSelected := btnDelete

    AppState.FullHistoryGui := myGui
    RefreshFullHistoryList()
    myGui.Show()
}

RefreshFullHistoryList() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    lv.Delete()
    if ( lv.GetCount( "Col" ) < 2 )
        lv.InsertCol( 1, , "Integer" )
    lv.ModifyCol( 1, 0 )

    filter := Trim( myGui.SearchBox.Text )
    maxDisplay := 50
    displayed := 0

    for i, item in AppState.History {
        if displayed >= maxDisplay {
            if displayed == maxDisplay
                lv.Add(, i, "... (" . ( AppState.History.Length - maxDisplay ) . " more items)" )
            break
        }

        display := StrReplace( SubStr( item[ "text" ], 1, 100 ), "`n", " " )
        if StrLen( item[ "text" ] ) > 100
            display .= "..."

        if filter != "" && !InStr( display, filter ) && !InStr( item[ "text" ], filter )
            continue

        lv.Add(, i, display )
        displayed++
    }

    lv.ModifyCol( 2, "AutoHdr" )
    myGui.chkSelectAll.Value := 0
}

ResizeFullHistoryGui( guiObj, minmax, width, height ) {
    lv := guiObj.ListView
    lv.Move( 10, 40, width - 20, height - 140 )

    btnPaste := guiObj.btnPaste
    btnPasteText := guiObj.btnPasteText
    btnClose := guiObj.btnClose
    chkSelectAll := guiObj.chkSelectAll
    btnDelete := guiObj.btnDeleteSelected

    btnPaste.GetPos(, , &w1 )
    btnPasteText.GetPos(, , &w2 )
    btnClose.GetPos(, , &w3 )
    spacing := 10

    totalBtnWidth := w1 + w2 + w3 + spacing * 2
    startX := width - totalBtnWidth - 10
    btnPaste.Move( startX, height - 80 )
    btnPasteText.Move( startX + w1 + spacing, height - 80 )
    btnClose.Move( startX + w1 + spacing + w2 + spacing, height - 80 )

    chkSelectAll.GetPos(, , &w4 )
    btnDelete.GetPos(, , &w5 )
    totalWidth2 := w4 + w5 + spacing
    startX2 := width - totalWidth2 - 10
    chkSelectAll.Move( startX2, height - 40 )
    btnDelete.Move( startX2 + w4 + spacing, height - 40 )
}
