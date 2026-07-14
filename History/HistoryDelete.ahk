#Requires AutoHotkey v2.0

DeleteHistoryItem( * ) {
    if AppState.SelectedIndex <= AppState.History.Length {
        HistoryManager.Delete( AppState.SelectedIndex )
        ShowToolTip( "已删除", 1000 )
    }
}

DeleteFromFullHistory( index ) {
    HistoryManager.Delete( index )
    RefreshFullHistoryList()
}
