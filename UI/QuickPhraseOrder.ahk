#Requires AutoHotkey v2.0

; Presentation order and search scoring for the quick phrase list.
;
; These helpers are pure: they read the fields of the phrase objects they are
; given and sort a derived copy, so the Store backing array and the persisted
; order are never mutated. Nothing here touches the GUI, the Store or any other
; application global, which lets the regression suite include this file and
; exercise the real ordering instead of matching its source text.
QuickPhraseFilterAndSort(allPhrases, query, rankByRelevance := false) {
    filter := Trim(query)

    ; The manager retains its literal-substring search. With no query, both
    ; views use the same category-first presentation order.
    if !rankByRelevance {
        phrases := []
        for phrase in allPhrases {
            if !QuickPhraseMatchesFilter(phrase, filter)
                continue
            phrases.Push(phrase)
        }
        if filter == ""
            return QuickPhraseSortByCategory(phrases)
        return phrases
    }

    ; Normalize whitespace so tabs/newlines work like ordinary spaces.
    filter := RegExReplace(filter, "\s+", " ")
    terms := []

    if filter != "" {
        for term in StrSplit(filter, A_Space)
            if term != ""
                terms.Push(term)
    }

    ; Group an empty query by category. Search terms use the relevance
    ; ranking below, with stored order as the tie-breaker.
    if !terms.Length {
        return QuickPhraseSortByCategory(allPhrases)
    }

    ; Rank a derived list; never mutate the store's backing array.
    ranked := []
    for phrase in allPhrases {
        score := QuickPhraseScorePhrase(phrase, terms, filter)
        if score < 0
            continue
        ranked.Push({phrase: phrase, score: score})
    }

    QuickPhraseSortRankedPhrases(ranked)

    phrases := []
    for item in ranked
        phrases.Push(item.phrase)
    return phrases
}

; Sorts a derived copy so the Store's backing array is never reordered.
QuickPhraseSortByCategory(phrases) {
    sorted := []
    for phrase in phrases
        sorted.Push(phrase)

    count := sorted.Length
    if count < 2
        return sorted

    root := count // 2
    while root > 0 {
        QuickPhraseCategorySiftDown(sorted, root, count)
        root -= 1
    }

    heapEnd := count
    while heapEnd > 1 {
        temp := sorted[1]
        sorted[1] := sorted[heapEnd]
        sorted[heapEnd] := temp
        heapEnd -= 1
        QuickPhraseCategorySiftDown(sorted, 1, heapEnd)
    }

    return sorted
}

QuickPhraseCategorySiftDown(entries, root, heapEnd) {
    while root * 2 <= heapEnd {
        child := root * 2
        if (
            child < heapEnd
            && QuickPhraseCompareDefault(entries[child], entries[child + 1]) < 0
        ) {
            child += 1
        }

        if QuickPhraseCompareDefault(entries[root], entries[child]) >= 0
            return

        temp := entries[root]
        entries[root] := entries[child]
        entries[child] := temp
        root := child
    }
}

; Category names sort case-insensitively; uncategorized phrases follow every
; named group. Within a group the manager's persisted order stays primary.
QuickPhraseCompareDefault(left, right) {
    leftCategory := Trim(left.category)
    rightCategory := Trim(right.category)
    leftUncategorized := leftCategory == ""
    rightUncategorized := rightCategory == ""
    if leftUncategorized != rightUncategorized
        return leftUncategorized ? 1 : -1

    categoryCompare := StrCompare(leftCategory, rightCategory, false)
    if categoryCompare != 0
        return categoryCompare

    return QuickPhraseComparePhrases(left, right)
}

QuickPhraseGroupMatches(phrase, group) {
    group := Trim(group)
    if group == ""
        return true
    return StrCompare(Trim(phrase.category), group, false) == 0
}

QuickPhraseMatchesFilter(phrase, filter) {
    if filter == ""
        return true

    return (
        InStr(phrase.name, filter, false)
        || InStr(phrase.category, filter, false)
        || InStr(phrase.content, filter, false)
    )
}

QuickPhraseScorePhrase(phrase, terms, query) {
    score := 0
    hasNameMatch := false
    hasCategoryMatch := false

    for term in terms {
        namePosition := InStr(phrase.name, term, false)
        categoryPosition := InStr(phrase.category, term, false)
        contentPosition := InStr(phrase.content, term, false)

        ; Every query term must match at least one field. Different terms
        ; may match different fields, which makes multi-term search useful.
        if !namePosition && !categoryPosition && !contentPosition
            return -1

        ; Use the strongest field match for each term rather than inflating
        ; a score merely because the same word also appears in the body.
        if namePosition {
            score += 100
            hasNameMatch := true
            if namePosition == 1
                score += 20
        } else if categoryPosition {
            score += 40
            hasCategoryMatch := true
        } else {
            score += 10
        }
    }

    ; Field tiers ensure a name hit outranks category-only and content-only
    ; hits, while exact/prefix name queries receive an additional boost.
    if hasNameMatch
        score += 10000
    else if hasCategoryMatch
        score += 1000

    if StrCompare(phrase.name, query, false) == 0
        score += 100000
    else if InStr(phrase.name, query, false) == 1
        score += 5000

    return score
}

QuickPhraseSortRankedPhrases(entries) {
    count := entries.Length
    if count < 2
        return entries

    root := count // 2
    while root > 0 {
        QuickPhraseRankedSiftDown(entries, root, count)
        root -= 1
    }

    heapEnd := count
    while heapEnd > 1 {
        temp := entries[1]
        entries[1] := entries[heapEnd]
        entries[heapEnd] := temp
        heapEnd -= 1
        QuickPhraseRankedSiftDown(entries, 1, heapEnd)
    }

    return entries
}

QuickPhraseRankedSiftDown(entries, root, heapEnd) {
    while root * 2 <= heapEnd {
        child := root * 2
        if (
            child < heapEnd
            && QuickPhraseCompareRanked(entries[child], entries[child + 1]) < 0
        ) {
            child += 1
        }

        if QuickPhraseCompareRanked(entries[root], entries[child]) >= 0
            return

        temp := entries[root]
        entries[root] := entries[child]
        entries[child] := temp
        root := child
    }
}

QuickPhraseCompareRanked(left, right) {
    if left.score != right.score
        return left.score > right.score ? -1 : 1

    ; Reuse established deterministic tie-breaking for equal scores.
    return QuickPhraseComparePhrases(left.phrase, right.phrase)
}

QuickPhraseComparePhrases(left, right) {
    if left.order != right.order
        return left.order < right.order ? -1 : 1

    nameCompare := StrCompare(left.name, right.name, false)
    if nameCompare != 0
        return nameCompare
    if left.id == right.id
        return 0

    return left.id < right.id ? -1 : 1
}
