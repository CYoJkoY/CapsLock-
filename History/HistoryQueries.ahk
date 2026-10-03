#Requires AutoHotkey v2.0

; Pure history query and paging logic shared by the GUI and headless checks.
HistoryPageRange(totalCount, displayedCount, maxDisplay) {
    return {
        start: displayedCount + 1,
        end: Min(maxDisplay, totalCount)
    }
}

HistorySearch(query) {
    indices := []
    query := Trim(query)

    if query == "" {
        for index, item in AppState.History
            indices.Push(index)
        return indices
    }

    for index, item in AppState.History {
        text := item["text"]
        if InStr(text, query) || InStr(HistoryPreviewText(text), query)
            indices.Push(index)
    }
    return indices
}

HistoryPreviewText(text) {
    display := RegExReplace(SubStr(text, 1, 80), "[\r\n\t\v\f]+", " ")
    return display . (StrLen(text) > 80 ? "…" : "")
}
