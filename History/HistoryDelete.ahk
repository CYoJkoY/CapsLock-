#Requires AutoHotkey v2.0

DeleteFromFullHistory(realIndex) {
    HistoryManager.Delete(realIndex)
    RefreshFullHistoryList()
}
