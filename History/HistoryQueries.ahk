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
        allTermsFound := true

        ; InStr is case-insensitive by default. Check the full text before
        ; creating any normalized copy so non-matching entries stay cheap.
        for searchTerm in searchTerms {
            if !InStr(entryText, searchTerm) {
                allTermsFound := false
                break
            }
        }

        if !allTermsFound
            continue

        previewText := StrLower(HistoryPreviewText(entryText))
        allTermsInPreview := true
        previewScore := 0
        for searchTerm in searchTerms {
            previewPosition := InStr(previewText, searchTerm)
            if previewPosition {
                previewScore += Max(0, 81 - previewPosition)
            } else {
                allTermsInPreview := false
            }
        }

        ; A single-term query should favor preview hits, not make every match
        ; a "contiguous phrase" match.
        phrasePosition := 0
        if searchTerms.Length > 1 {
            normalizedText := RegExReplace(entryText, "\s+", " ")
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

; O(n log n) heap sort keeps per-keystroke ranking bounded for large histories.
HistorySortRankedResults(entries) {
    count := entries.Length
    if count < 2
        return entries

    root := count // 2
    while root > 0 {
        HistoryRankedSiftDown(entries, root, count)
        root -= 1
    }

    heapEnd := count
    while heapEnd > 1 {
        temp := entries[1]
        entries[1] := entries[heapEnd]
        entries[heapEnd] := temp
        heapEnd -= 1
        HistoryRankedSiftDown(entries, 1, heapEnd)
    }

    return entries
}

HistoryRankedSiftDown(entries, root, heapEnd) {
    while root * 2 <= heapEnd {
        child := root * 2
        if (
            child < heapEnd
            && HistoryCompareRankedResults(entries[child], entries[child + 1]) < 0
        ) {
            child += 1
        }

        if HistoryCompareRankedResults(entries[root], entries[child]) >= 0
            return

        temp := entries[root]
        entries[root] := entries[child]
        entries[child] := temp
        root := child
    }
}

HistoryCompareRankedResults(leftEntry, rightEntry) {
    if leftEntry.tier != rightEntry.tier
        return leftEntry.tier < rightEntry.tier ? -1 : 1
    if leftEntry.score != rightEntry.score
        return leftEntry.score > rightEntry.score ? -1 : 1
    if leftEntry.order == rightEntry.order
        return 0
    return leftEntry.order < rightEntry.order ? -1 : 1
}

HistoryPreviewText(text) {
    display := RegExReplace(SubStr(text, 1, 80), "[\r\n\t\v\f]+", " ")
    return display . (StrLen(text) > 80 ? "…" : "")
}
