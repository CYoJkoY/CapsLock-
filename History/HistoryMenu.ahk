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
        CapturePasteTarget()
    }

    menuItems := []
    total := AppState.History.Length
    displayCount := Min(total, AppState.MAX_VISIBLE_MENU)

    Loop displayCount {
        idx := A_Index
        item := AppState.History[idx]
        timeInfo := SubStr(item["time"], 12, 5)
        label := idx ". [" timeInfo "] " CustomMenu.ClipLabel(item["text"], 32)

        menuItems.Push({
            label: label,
            callback: CreateHistoryPasteCallback(idx),
            isSep: false
        })
    }

    if total > AppState.MAX_VISIBLE_MENU {
        menuItems.Push({
            label: "",
            callback: "",
            isSep: true
        })

        menuItems.Push({
            label: "📋 " Lang("HISTORY_MENU_VIEW_FULL", "", total),
            callback: CreateShowFullHistoryCallback(),
            isSep: false
        })
    }

    CustomMenu.ShowWithItems(AppState.MenuPosX, AppState.MenuPosY, menuItems)
}

CreateHistoryPasteCallback(index) {
    return (*) => PasteHistoryByIndex(index)
}

CreateShowFullHistoryCallback() {
    return (*) => ShowFullHistoryGui()
}

PasteHistoryByIndex(index) {
    item := HistoryManager.Get(index)
    if !IsObject(item) {
        ShowToolTip(Lang("MSG_NO_HISTORY"), 1200)
        return
    }

    PasteAsFile(item)
}
