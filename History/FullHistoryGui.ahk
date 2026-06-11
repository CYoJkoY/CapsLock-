#Requires AutoHotkey v2.0

ShowFullHistoryGui( ItemName?, ItemPos?, MyMenu? ) {
    global clipboardHistory, fullHistoryGui, targetWindow

    targetWindow := WinExist( "A" )

    if ( fullHistoryGui ) {
        try {
            if WinExist( "ahk_id " fullHistoryGui.Hwnd ) {
                WinActivate( "ahk_id " fullHistoryGui.Hwnd )
                _RefreshFullHistoryList()
                return
            }
        } catch {
            fullHistoryGui := ""
        }
    }

    fullHistoryGui := Gui( "+Resize +AlwaysOnTop", "Clipboard History (Full)" )
    fullHistoryGui.SetFont( "s10", "Microsoft YaHei" )
    fullHistoryGui.OnEvent( "Close", ( * ) => ( fullHistoryGui.Destroy(), fullHistoryGui := "" ) )
    fullHistoryGui.OnEvent( "Escape", ( * ) => ( fullHistoryGui.Destroy(), fullHistoryGui := "" ) )
    fullHistoryGui.OnEvent( "Size", _ResizeFullHistoryGui )

    lv := fullHistoryGui.Add( "ListView", "r20 w600 Checked Multi Grid", [
        "#",
        "Content (first 100 chars)"
    ] )
    lv.OnEvent( "DoubleClick", _OnFullHistoryDoubleClick )
    lv.OnEvent( "ContextMenu", _OnFullHistoryContextMenu )
    lv.OnEvent( "ItemCheck", _OnItemCheck )
    fullHistoryGui.ListView := lv

    btnPaste := fullHistoryGui.Add( "Button", "Default", "Paste as File" )
    btnPaste.OnEvent( "Click", ( * ) => _PasteSelectedFromFullHistory() )
    fullHistoryGui.btnPaste := btnPaste

    btnClose := fullHistoryGui.Add( "Button", "x+10 yp", "Close" )
    btnClose.OnEvent( "Click", ( * ) => fullHistoryGui.Destroy() )
    fullHistoryGui.btnClose := btnClose

    chkSelectAll := fullHistoryGui.Add( "CheckBox", "x10 y+20", "Select All" )
    chkSelectAll.OnEvent( "Click", _OnSelectAllClicked )
    fullHistoryGui.chkSelectAll := chkSelectAll

    btnDeleteSelected := fullHistoryGui.Add( "Button", "x+10 yp", "Delete Selected" )
    btnDeleteSelected.OnEvent( "Click", _OnDeleteSelected )
    fullHistoryGui.btnDeleteSelected := btnDeleteSelected

    _RefreshFullHistoryList()
    fullHistoryGui.Show()
}
