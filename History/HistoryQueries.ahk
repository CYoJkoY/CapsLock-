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
    searchQuery := StrLower(RegExReplace(Trim(query), "\s+", " "))
    searchTerms := []

    if searchQuery != "" {
        for searchTerm in StrSplit(searchQuery, A_Space) {
            if searchTerm != ""
                searchTerms.Push(searchTerm)
        }
    }

    ; Keep the existing newest-first order when no query terms are present.
    if !searchTerms.Length {
        for historyIndex, historyItem in AppState.History
            indices.Push(historyIndex)
        return indices
    }

    rankedEntries := []
    for historyIndex, historyItem in AppState.History {
        entryText := historyItem["text"]
        entryTextLower := StrLower(entryText)
        previewText := StrLower(HistoryPreviewText(entryText))
        allTermsFound := true
        allTermsInPreview := true
        previewScore := 0

        for searchTerm in searchTerms {
            if !InStr(entryTextLower, searchTerm) {
                allTermsFound := false
                break
            }

            previewPosition := InStr(previewText, searchTerm)
            if previewPosition {
                previewScore += Max(0, 81 - previewPosition)
            } else {
                allTermsInPreview := false
            }
        }

        if !allTermsFound
            continue

        ; A single-term query should favor preview hits, not make every match
        ; a "contiguous phrase" match.
        phrasePosition := 0
        if searchTerms.Length > 1 {
            normalizedText := RegExReplace(entryTextLower, "\s+", " ")
            phrasePosition := InStr(normalizedText, searchQuery)
        }

        if phrasePosition {
            ; A contiguous multi-term phrase outranks a non-contiguous match.
            tier := 1
            relevanceScore := 10000 + Max(0, 1000 - phrasePosition)
        } else if allTermsInPreview {
            ; If all terms are visible in the list preview, rank ahead of
            ; matches that require searching deeper inside the clipboard entry.
            tier := 2
            relevanceScore := previewScore
        } else {
            tier := 3
            relevanceScore := previewScore
        }

        rankedEntries.Push({
            index: historyIndex,
            tier: tier,
            score: relevanceScore,
            order: historyIndex
        })
    }

    HistorySortRankedResults(rankedEntries)
    for rankedEntry in rankedEntries
        indices.Push(rankedEntry.index)

    return indices
}

HistoryPreviewText(text) {
    display := RegExReplace(SubStr(text, 1, 80), "[\r\n\t\v\f]+", " ")
    return display . (StrLen(text) > 80 ? "…" : "")
}
