#Requires AutoHotkey v2.0

ShowHistoryMenu(isReturning := false) {
    if AppState.History.Length == 0 {
        ShowToolTip(Lang("MSG_NO_HISTORY"), 1500)
        return
    }

    if !isReturning {
        MouseGetPos(&x, &y)
        AppState.MenuPosX := x
        AppState.MenuPosY := y
    }

    menuItems := []
    total := AppState.History.Length
    displayCount := Min(total, AppState.MAX_VISIBLE_MENU)

    loop displayCount {
        index := A_Index
        item := AppState.History[index]
        content := item["text"]
        display := StrReplace(SubStr(content, 1, 50), "`n", " ")
        if StrLen(content) > 50
            display .= "…"

        timeInfo := SubStr(item["time"], 12, 5)
        idx := index

        menuItems.Push({
            label: idx ". [" timeInfo "] " display,
            callback: (*) => ShowActionPicker(idx),
            isSep: false
        })
    }

    if total > AppState.MAX_VISIBLE_MENU {
        menuItems.Push({label: "", callback: "", isSep: true})
        menuItems.Push({
            label: "📋 " Lang("HISTORY_MENU_VIEW_FULL", , total),
            callback: (*) => ShowFullHistoryGui(),
            isSep: false
        })
    }

    CustomMenu.ShowWithItems(AppState.MenuPosX, AppState.MenuPosY, menuItems)
}

ShowActionPicker(index) {
    AppState.SelectedIndex := index
    AppState.SelectedItem := AppState.History[index]

    MouseGetPos(&x, &y)

    actionItems := [
        {label: "📄 " Lang("CONTEXT_PASTE_FILE"), callback: (*) => PasteAsFile(AppState.SelectedItem), isSep: false},
        {label: "👁️ " Lang("CONTEXT_PREVIEW"), callback: (*) => ShowPreviewGui(AppState.SelectedItem["text"]), isSep: false},
        {label: "🗑️ " Lang("CONTEXT_DELETE"), callback: (*) => (HistoryManager.Delete(AppState.SelectedIndex), ShowToolTip(Lang("MSG_DELETED"), 1000)), isSep: false},
        {label: "", callback: "", isSep: true},
        {label: "↩️ " Lang("CONTEXT_BACK"), callback: (*) => SetTimer(() => ShowHistoryMenu(true), -10), isSep: false}
    ]

    CustomMenu.ShowWithItems(x, y, actionItems)
}

ActionPickerHandler( ItemName, ItemPos, MyMenu ) {
    AppState.SelectedIndex := ItemPos
    AppState.SelectedItem := AppState.History[ ItemPos ]
    action := Menu()
    action.Add( Lang( "CONTEXT_PASTE_FILE" ), ( * ) => PasteAsFile( AppState.SelectedItem ) )
    action.Add( Lang( "CONTEXT_PREVIEW" ), ( * ) => ShowPreviewGui( AppState.SelectedItem[ "text" ] ) )
    action.Add( Lang( "CONTEXT_DELETE" ), ( * ) => ( HistoryManager.Delete( AppState.SelectedIndex ), ShowToolTip( Lang( "MSG_DELETED" ), 1000 ) ) )
    action.Add()
    action.Add( Lang( "CONTEXT_BACK" ), ( * ) => SetTimer( () => ShowHistoryMenu( true ), -10 ) )
    action.Show()
}
