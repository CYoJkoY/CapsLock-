#Requires AutoHotkey v2.0

DeleteHistoryItem( * ) {
    if AppState.SelectedIndex <= AppState.History.Length {
        HistoryManager.Delete( AppState.SelectedIndex )
        ShowToolTip( Lang( "MSG_DELETED" ), 1000 )
    }
}

DeleteFromFullHistory( realIndex ) {
    HistoryManager.Delete( realIndex )
    RefreshFullHistoryList()
}
