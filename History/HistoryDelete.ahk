#Requires AutoHotkey v2.0

DeleteHistoryItem( * ) {
    global clipboardHistory, selectedIndex

    if ( selectedIndex <= clipboardHistory.Length ) {
        clipboardHistory.RemoveAt( selectedIndex )
        SaveHistory()
        ShowToolTip( "Deleted", 1000 )
    }
}

DeleteFromFullHistory( index ) {
    global clipboardHistory, fullHistoryGui

    if ( index <= clipboardHistory.Length ) {
        clipboardHistory.RemoveAt( index )
        SaveHistory()
        _RefreshFullHistoryList()
    }
}
