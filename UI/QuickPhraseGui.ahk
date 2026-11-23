#Requires AutoHotkey v2.0

; AppState is provided by the root script's Config\Globals.ahk include.
IsSet(AppState)

ShowQuickPhraseSelector() {
    if IsObject(AppState.QuickPhraseGui) {
        try {
            if WinExist("ahk_id " AppState.QuickPhraseGui.Hwnd) {
                AppState.QuickPhraseGui.Show()
                WinActivate("ahk_id " AppState.QuickPhraseGui.Hwnd)
                QuickPhraseRefreshSelector(AppState.QuickPhraseGui)
                return
            }
        } catch {
            AppState.QuickPhraseGui := ""
        }
    }

    ownerOption := IsObject(AppState.QuickPhraseGui)
        ? " +Owner" AppState.QuickPhraseGui.Hwnd
        : ""
    myGui := Gui(
        ownerOption " -MaximizeBox -MinimizeBox",
        Lang("GUI_QUICK_PHRASE_TITLE", "Quick Phrases")
    )
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, Lang("GUI_QUICK_PHRASE_TITLE", "Quick Phrases"), 640)
    ThemeHelper.AddSubtitle(
        myGui,
        Lang("GUI_QUICK_PHRASE_SUBTITLE", "Search by name or content. Press Enter or double-click to insert."),
        640
    )
    ThemeHelper.AddSeparator(myGui, 640)

    search := myGui.Add("Edit", "w420 r1 y+12 xm " ThemeHelper.GetEditOptions(), "")
    ThemeHelper.StyleEdit(search)
    groupOptions := QuickPhraseCategoryOptions()
    groupFilter := myGui.Add("DropDownList", "x+10 yp w210 Choose1 c" Theme.Text " Background" Theme.Control, groupOptions)
    ThemeHelper.StyleComboBox(groupFilter)
    list := myGui.Add(
        "ListView",
        "w640 r12 y+10 xm -Multi " ThemeHelper.GetLVOptions(),
        ["ID", Lang("GUI_QUICK_PHRASE_COL_NAME", "Name"), Lang("GUI_QUICK_PHRASE_COL_CATEGORY", "Category"), Lang("GUI_QUICK_PHRASE_COL_PREVIEW", "Preview")]
    )
    list.ModifyCol(1, 0)
    list.ModifyCol(2, 190)
    list.ModifyCol(3, 120)
    list.ModifyCol(4, 330)
    ThemeHelper.StyleListView(list)

    status := myGui.Add("Text", "w640 y+8 xm", "")
    useBtn := ThemeHelper.AddButton(myGui, "Default w110 y+12 xm", Lang("GUI_QUICK_PHRASE_USE", "Use"), "primary")
    manageBtn := ThemeHelper.AddButton(myGui, "x+8 yp w110", Lang("GUI_QUICK_PHRASE_MANAGE", "Manage"))
    closeBtn := ThemeHelper.AddButton(myGui, "x+8 yp w90", Lang("GUI_FULL_CLOSE", "Close"))

    myGui.SearchBox := search
    myGui.GroupFilter := groupFilter
    myGui.GroupFilterOptionCount := groupOptions.Length
    myGui.ListView := list
    myGui.Status := status
    myGui.OnEvent("Escape", (*) => CloseQuickPhraseSelector(myGui))
    myGui.OnEvent("Close", (*) => CloseQuickPhraseSelector(myGui))
    search.OnEvent("Change", (*) => QuickPhraseRefreshSelector(myGui))
    groupFilter.OnEvent("Change", (*) => QuickPhraseGroupFilterChanged(myGui))
    useBtn.OnEvent("Click", (*) => QuickPhraseUseSelected(myGui))
    list.OnEvent("DoubleClick", (*) => QuickPhraseUseSelected(myGui))
    manageBtn.OnEvent("Click", (*) => QuickPhraseOpenManager(myGui))
    closeBtn.OnEvent("Click", (*) => CloseQuickPhraseSelector(myGui))

    AppState.QuickPhraseGui := myGui
    ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
    myGui.Show("w680 h470")
    search.Focus()
    QuickPhraseRefreshSelector(myGui)
}

QuickPhraseDestroySelector(myGui) {
    AppState.QuickPhraseGui := ""
    try myGui.Destroy()
}

QuickPhraseDestroyVariableDialog(myGui) {
    AppState.QuickPhraseVariableGui := ""
    try myGui.Hide()
    try myGui.Destroy()
}

CloseQuickPhraseSelector(myGui) {
    QuickPhraseDestroySelector(myGui)
    AppState.QuickPhraseExternalTarget := ""
    return true
}

QuickPhraseOpenManager(selectorGui) {
    try selectorGui.Hide()
    ShowQuickPhraseManager(true)
}

QuickPhraseGroupFilterChanged(myGui) {
    if IsObject(myGui) && myGui.HasProp("RefreshingGroupFilter") && myGui.RefreshingGroupFilter
        return

    if myGui == AppState.QuickPhraseManagerGui
        QuickPhraseRefreshManager(myGui)
    else
        QuickPhraseRefreshSelector(myGui)
}

QuickPhraseRefreshSelector(myGui) {
    result := QuickPhraseRefreshList(myGui, 100, false, true)
    if !IsObject(result)
        return

    if result.total == 0
        myGui.Status.Text := Lang("GUI_QUICK_PHRASE_EMPTY", "No saved quick phrases. Use Manage to create one.")
    else
        myGui.Status.Text := Lang("GUI_QUICK_PHRASE_STATUS", "{1} quick phrase(s) available.", result.visible)
}

QuickPhraseRefreshList(myGui, previewLength, selectFirst := false, rankByRelevance := false) {
    if !IsObject(myGui)
        return ""
    if !myGui.HasProp("ListView") || !myGui.HasProp("SearchBox")
        return ""

    list := myGui.ListView
    searchBox := myGui.SearchBox
    if !IsObject(list) || !IsObject(searchBox)
        return ""

    selectedId := QuickPhraseGetSelectedId(list)
    allPhrases := QuickPhraseStore.GetAll()
    group := QuickPhraseSelectedGroup(myGui)
    phrasesForView := allPhrases
    if group != "" {
        phrasesForView := []
        for phrase in allPhrases {
            if QuickPhraseGroupMatches(phrase, group)
                phrasesForView.Push(phrase)
        }
    }
    phrases := QuickPhraseFilterAndSort(phrasesForView, searchBox.Text, rankByRelevance)

    list.Delete()
    selectedRow := 0
    for phrase in phrases {
        row := list.Add(
            , phrase.id,
            phrase.name,
            phrase.category,
            QuickPhrasePreview(phrase.content, previewLength)
        )
        if phrase.id == selectedId
            selectedRow := row
    }

    if !selectedRow && selectFirst && phrases.Length
        selectedRow := 1
    if selectedRow
        list.Modify(selectedRow, "Select")

    return {
        total: allPhrases.Length,
        visible: phrases.Length
    }
}

QuickPhraseGetSelectedId(list) {
    if !IsObject(list)
        return 0

    row := list.GetNext(0, "Focused")
    if !row
        row := list.GetNext(0)
    if !row
        return 0

    idText := list.GetText(row, 1)
    if !(idText ~= "^\d+$")
        return 0

    return Integer(idText)
}

QuickPhraseCategoryOptions() {
    categories := [Lang("GUI_QUICK_PHRASE_ALL_GROUPS", "All groups")]
    seen := Map()
    for phrase in QuickPhraseStore.GetAll() {
        category := Trim(phrase.category)
        categoryKey := StrLower(category)
        if category == "" || seen.Has(categoryKey)
            continue
        seen[categoryKey] := true
        categories.Push(category)
    }
    return categories
}

QuickPhraseSelectedGroup(myGui) {
    if !IsObject(myGui) || !myGui.HasProp("GroupFilter")
        return ""

    groupFilter := myGui.GroupFilter
    if !IsObject(groupFilter) || groupFilter.Value == 1
        return ""

    return Trim(groupFilter.Text)
}

QuickPhraseHandleHotkey(*) {
    if !QuickPhraseHotkeyAvailable()
        return

    target := QuickPhraseCaptureExternalTarget()
    if !IsObject(target)
        return

    AppState.QuickPhraseExternalTarget := target
    ShowQuickPhraseSelector()
}

QuickPhraseCaptureExternalTarget() {
    windowHwnd := WinExist("A")

    if !windowHwnd || QuickPhraseIsInternalWindow(windowHwnd)
        return ""

    controlHwnd := 0
    controlClass := ""

    try {
        controlHwnd := ControlGetFocus("ahk_id " windowHwnd)
        if controlHwnd
            controlClass := WinGetClass("ahk_id " controlHwnd)
    } catch {
        controlHwnd := 0
        controlClass := ""
    }

    return {
        window: windowHwnd,
        control: controlHwnd,
        controlClass: controlClass
    }
}

QuickPhraseUseSelected(selectorGui) {
    if AppState.QuickPhraseTransactionActive
        return true

    row := selectorGui.ListView.GetNext(0, "Focused")
    if !row
        row := selectorGui.ListView.GetNext(0)

    if !row {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_SELECT", "Please select a quick phrase."), 1500)
        return true
    }

    idText := selectorGui.ListView.GetText(row, 1)
    if !(idText ~= "^\d+$")
        return true

    phrase := QuickPhraseStore.GetById(Integer(idText))
    if !IsObject(phrase)
        return true

    AppState.QuickPhraseTransactionActive := true
    QuickPhraseDestroySelector(selectorGui)

    ; Let the selector's GUI event thread unwind before opening the
    ; variable-input dialog. The variable workflow must not be nested inside
    ; the selector's Click/DoubleClick callback.
    SetTimer(
        QuickPhraseExecutePhrase.Bind(phrase),
        -1
    )
    return true
}

QuickPhraseExecutePhrase(phrase) {
    reopenSelector := false
    ok := false
    errorMessage := ""

    try {
        variables := QuickPhraseExtractVariables(phrase.content)

        if variables.Length == 0 {
            rendered := QuickPhraseRenderTemplate(phrase.content, Map())
            ok := QuickPhrasePasteText(
                rendered.text,
                "",
                rendered.cursorOffset
            )
        } else {
            result := ShowQuickPhraseVariableDialog(
                phrase,
                variables
            )

            if !result.ok {
                reopenSelector := result.cancelled
                return
            }

            ; The dialog is destroyed before the captured external target
            ; receives the rendered text and optional cursor repositioning.
            ok := QuickPhrasePasteText(
                result.text,
                "",
                result.cursorOffset
            )
        }
    } catch as caughtError {
        errorMessage := caughtError.Message
    } finally {
        AppState.QuickPhraseTransactionActive := false

        if reopenSelector
            ShowQuickPhraseSelector()
        else
            AppState.QuickPhraseExternalTarget := ""
    }

    if errorMessage != "" {
        ShowToolTip(
            errorMessage,
            2200
        )
        return
    }

    if !ok {
        ShowToolTip(
            Lang(
                "MSG_QUICK_PHRASE_PASTE_FAILED",
                "Could not insert the quick phrase."
            ),
            2200
        )
    }
}

QuickPhrasePreview(text, maxChars := 80) {
    preview := Trim(RegExReplace(String(text), "[\r\n\t\v\f]+", " "))
    if preview == ""
        return "(empty)"
    return StrLen(preview) > maxChars ? SubStr(preview, 1, maxChars - 1) "…" : preview
}

QuickPhraseExtractVariables(template) {
    variables := []
    seen := Map()
    pattern := "\{\{\s*([^{}\r\n]+?)\s*\}\}"
    pos := 1

    while RegExMatch(template, pattern, &match, pos) {
        name := Trim(match[1])
        if (
            name != ""
            && !QuickPhraseIsBuiltInVariable(name)
            && !seen.Has(name)
        ) {
            variables.Push(name)
            seen[name] := true
        }
        pos := match.Pos + match.Len
    }
    return variables
}

QuickPhraseIsBuiltInVariable(name) {
    normalized := StrLower(Trim(name))
    return (
        normalized == "date"
        || normalized == "time"
        || normalized == "datetime"
        || normalized == "clipboard"
        || normalized == "cursor"
        || RegExMatch(name, "i)^(date|time):.+$")
    )
}

QuickPhraseResolveBuiltInVariable(name) {
    trimmed := Trim(name)
    normalized := StrLower(trimmed)

    if normalized == "date"
        return FormatTime(, "yyyy-MM-dd")
    if normalized == "time"
        return FormatTime(, "HH:mm:ss")
    if normalized == "datetime"
        return FormatTime(, "yyyy-MM-dd HH:mm:ss")
    if normalized == "clipboard"
        return A_Clipboard

    if RegExMatch(trimmed, "i)^date:(.+)$", &match)
        return FormatTime(, match[1])
    if RegExMatch(trimmed, "i)^time:(.+)$", &match)
        return FormatTime(, match[1])

    return ""
}

QuickPhraseApplyVariables(template, values) {
    return QuickPhraseRenderTemplate(template, values).text
}

QuickPhraseRenderTemplate(template, values) {
    result := ""
    cursorOffset := -1
    pattern := "\{\{\s*([^{}\r\n]+?)\s*\}\}"
    pos := 1

    while RegExMatch(template, pattern, &match, pos) {
        if match.Pos > pos
            result .= SubStr(template, pos, match.Pos - pos)

        name := Trim(match[1])
        normalized := StrLower(name)

        if normalized == "cursor" {
            if cursorOffset < 0
                cursorOffset := StrLen(result)
            replacement := ""
        } else if values.Has(name) {
            replacement := values[name]
        } else if QuickPhraseIsBuiltInVariable(name) {
            replacement := QuickPhraseResolveBuiltInVariable(name)
        } else {
            replacement := match[0]
        }

        result .= replacement
        pos := match.Pos + match.Len
    }

    return {
        text: result . SubStr(template, pos),
        cursorOffset: cursorOffset
    }
}

ShowQuickPhraseVariableDialog(phrase, variables) {
    result := {
        ok: false,
        cancelled: false,
        text: ""
    }

    ; etxt is the reserved free-form multiline variable. Keep ordinary
    ; variables compact and place the multiline field on its own row.
    normalVariables := []
    etxtName := ""

    for name in variables {
        if (
            StrLower(Trim(name)) == "etxt"
            && etxtName == ""
        ) {
            etxtName := name
        } else {
            normalVariables.Push(name)
        }
    }

    CONTENT_WIDTH := 640
    COLUMN_WIDTH := 300
    COLUMN_X := [16, 336]
    LABEL_GAP := 6
    SECTION_GAP := 16
    BOTTOM_GAP := 12
    BOTTOM_MARGIN := 16
    BUTTON_H := 32

    ; A variable name can wrap over several lines, so every label is measured
    ; before the input below it is positioned. The old fixed label height left
    ; wrapped names covered by their own input field.
    rowCount := Integer(Ceil(normalVariables.Length / 2))

    myGui := Gui(
        "-MaximizeBox -MinimizeBox",
        Lang(
            "GUI_QUICK_PHRASE_VARIABLE_TITLE",
            "Fill phrase variables"
        )
    )

    ThemeHelper.StyleGui(myGui)

    ThemeHelper.AddTitle(
        myGui,
        Lang(
            "GUI_QUICK_PHRASE_VARIABLE_TITLE",
            "Fill phrase variables"
        ),
        CONTENT_WIDTH
    )

    ThemeHelper.AddSubtitle(
        myGui,
        Lang(
            "GUI_QUICK_PHRASE_VARIABLE_HINT",
            "Fields follow first appearance order; repeated names are requested once."
        ),
        CONTENT_WIDTH
    )

    separator := ThemeHelper.AddSeparator(myGui, CONTENT_WIDTH)

    ; The header grows with the active font and text scaling, so the content
    ; start is taken from where the separator actually landed.
    separator.GetPos(&separatorX, &separatorY, &separatorWidth, &separatorHeight)
    contentTop := separatorY + separatorHeight + SECTION_GAP

    ; Labels are created first and left at y0 until the whole layout is known.
    myGui.SetFont("s9 c" Theme.TextSecondary, ThemeHelper.ReadingStack())

    variableLabels := []
    variableLabelH := []
    rowLabelH := []

    for index, name in normalVariables {
        column := index <= rowCount ? 0 : 1
        variableLabels.Push(
            myGui.Add("Text", "x" COLUMN_X[column + 1] " y0 w" COLUMN_WIDTH, name)
        )
    }

    for label in variableLabels {
        label.GetPos(&labelX, &labelY, &labelWidth, &labelHeight)
        variableLabelH.Push(labelHeight)
    }

    ; Rows pair the two columns, so a row is as tall as its tallest label.
    Loop rowCount {
        row := A_Index
        paired := row + rowCount
        rowLabelH.Push(
            paired <= normalVariables.Length
                ? Max(variableLabelH[row], variableLabelH[paired])
                : variableLabelH[row]
        )
    }

    ; etxt keeps its own full-width row, and the preview label is measured here
    ; because the fit test below needs the real heights.
    etxtLabel := ""
    etxtLabelH := 0
    if etxtName != "" {
        etxtLabel := myGui.Add("Text", "x16 y0 w" CONTENT_WIDTH, etxtName)
        etxtLabel.GetPos(&etxtLabelX, &etxtLabelY, &etxtLabelWidth, &etxtLabelHeight)
        etxtLabelH := etxtLabelHeight
    }

    myGui.SetFont("s10 c" Theme.Text, ThemeHelper.ReadingStack())

    previewLabel := myGui.Add(
        "Text",
        "x16 y0",
        Lang(
            "GUI_QUICK_PHRASE_PREVIEW",
            "Preview"
        )
    )
    previewLabel.GetPos(&previewLabelX, &previewLabelY0, &previewLabelWidth, &previewLabelHeight)

    ; Layout tiers from roomy to compact: a taller dialog is preferred, and the
    ; later tiers trade input height for vertical room on short screens.
    layoutTiers := [
        {editH: 62, rowGap: 14, previewH: 120, etxtH: 96},
        {editH: 52, rowGap: 12, previewH: 110, etxtH: 88},
        {editH: 42, rowGap: 10, previewH: 100, etxtH: 80},
        {editH: 34, rowGap: 8, previewH: 90, etxtH: 72},
        {editH: 26, rowGap: 6, previewH: 80, etxtH: 64}
    ]

    ; Gui coordinates are DPI-scaled logical units while the screen metrics are
    ; physical pixels, so the work area has to be converted before it can bound
    ; the layout. Comparing them directly made every size test too generous on
    ; scaled displays and the dialog was drawn taller than the screen.
    dipScale := 96 / A_ScreenDPI
    monitor := MonitorGetPrimary()
    if !MonitorGetWorkArea(monitor, &workLeft, &workTop, &workRight, &workBottom) {
        workTop := 0
        workBottom := A_ScreenHeight
    }
    ; Room for the caption and frame AHK adds around the client area.
    WINDOW_CHROME_H := 44
    availableH := Round((workBottom - workTop) * dipScale) - WINDOW_CHROME_H

    GetVarsHeight(candidate) {
        total := 0
        for labelHeight in rowLabelH
            total += labelHeight + LABEL_GAP + candidate.editH + candidate.rowGap
        return total
    }

    GetEtxtHeight(candidate) {
        if etxtName == ""
            return 0
        return 8 + etxtLabelH + LABEL_GAP + candidate.etxtH
    }

    ; Section gap, preview label, preview field, a gap, the buttons and the
    ; bottom margin. This mirrors the construction below exactly so the fit
    ; test and the window height agree.
    GetBottomHeight(candidate) {
        return SECTION_GAP + previewLabelHeight + LABEL_GAP + candidate.previewH
            + BOTTOM_GAP + BUTTON_H + BOTTOM_MARGIN
    }

    tier := ""
    for candidate in layoutTiers {
        total := contentTop + GetVarsHeight(candidate) + GetEtxtHeight(candidate)
            + GetBottomHeight(candidate)
        if total <= availableH {
            tier := candidate
            break
        }
    }

    ; When even the most compact tier overflows, the rows are split over pages.
    ; Clamping the window height while keeping fixed positions (the old
    ; behaviour) hid the lower inputs together with the preview and buttons.
    paginate := false
    pagerH := 0
    if !IsObject(tier) {
        tier := layoutTiers[layoutTiers.Length]
        paginate := true
        pagerH := BOTTOM_GAP + BUTTON_H
    }

    rowPage := []
    rowOffset := []
    pageBudget := availableH - (contentTop + GetEtxtHeight(tier) + pagerH + GetBottomHeight(tier))

    ; A plain greedy fill leaves the last page almost empty (for example
    ; 9 + 9 + 2 rows), so the greedy pass only decides how many pages are
    ; needed and the rows are then spread evenly over them.
    minimumPages := 1
    offset := 0

    for row, labelHeight in rowLabelH {
        rowH := labelHeight + LABEL_GAP + tier.editH + tier.rowGap
        if (paginate && offset > 0 && offset + rowH > pageBudget) {
            minimumPages += 1
            offset := 0
        }
        offset += rowH
    }

    ; Each page takes its share of the rows still unplaced, so 100 rows over
    ; 12 pages become 4 x 9 + 8 x 8 rows instead of 11 x 9 + 1.
    rowsLeft := rowLabelH.Length
    pagesLeft := minimumPages
    rowsPerPage := paginate
        ? Integer(Ceil(rowsLeft / pagesLeft))
        : rowLabelH.Length

    currentPageNumber := 1
    rowsOnPage := 0
    offset := 0

    for row, labelHeight in rowLabelH {
        rowH := labelHeight + LABEL_GAP + tier.editH + tier.rowGap
        if (
            paginate
            && offset > 0
            && (offset + rowH > pageBudget || rowsOnPage >= rowsPerPage)
        ) {
            currentPageNumber += 1
            offset := 0
            rowsOnPage := 0
            pagesLeft := Max(pagesLeft - 1, 1)
            rowsPerPage := Integer(Ceil(rowsLeft / pagesLeft))
        }
        rowPage.Push(currentPageNumber)
        rowOffset.Push(offset)
        offset += rowH
        rowsOnPage += 1
        rowsLeft -= 1
    }
    pageCount := paginate ? currentPageNumber : 1

    varsHeight := 0
    if paginate {
        pageBottom := Map()
        for row, labelHeight in rowLabelH {
            rowH := labelHeight + LABEL_GAP + tier.editH + tier.rowGap
            bottom := rowOffset[row] + rowH
            known := pageBottom.Has(rowPage[row]) ? pageBottom[rowPage[row]] : 0
            if bottom > known
                pageBottom[rowPage[row]] := bottom
        }
        for pageIndex, bottom in pageBottom
            varsHeight := Max(varsHeight, bottom)
    } else {
        varsHeight := offset
    }

    controls := []
    variableEdits := []
    variablePages := []

    ; Every variable can contain structured/multiline text (for example YAML).
    ; Keep the compact two-column layout, but make each input a true multiline
    ; Edit control so pasted line breaks are preserved.
    normalEditOptions := "Multi WantReturn VScroll " ThemeHelper.GetEditOptions()

    myGui.SetFont("s10 c" Theme.Text, ThemeHelper.ReadingStack())

    for index, name in normalVariables {
        column := index <= rowCount ? 0 : 1
        row := column ? index - rowCount : index
        labelY := contentTop + rowOffset[row]
        editY := labelY + variableLabelH[index] + LABEL_GAP

        editControl := myGui.Add(
            "Edit",
            "x" COLUMN_X[column + 1]
            " y" editY
            " w" COLUMN_WIDTH
            " h" tier.editH
            " " normalEditOptions,
            ""
        )

        ThemeHelper.StyleEdit(editControl)
        variableLabels[index].Move(COLUMN_X[column + 1], labelY)

        variableEdits.Push(editControl)
        variablePages.Push(rowPage[row])
        controls.Push({
            name: name,
            edit: editControl,
            page: rowPage[row]
        })
    }

    cursorY := contentTop + varsHeight

    pagerLabel := ""
    prevBtn := ""
    nextBtn := ""

    if paginate {
        ; Centred against the pager buttons rather than the row top.
        pagerLabel := myGui.Add("Text", "x16 y" (cursorY + BOTTOM_GAP + 7) " w300", "")
        prevBtn := ThemeHelper.AddButton(
            myGui,
            "x456 y" cursorY + BOTTOM_GAP " w90",
            Lang("GUI_QUICK_PHRASE_PREV", "Previous")
        )
        nextBtn := ThemeHelper.AddButton(
            myGui,
            "x+8 yp w90",
            Lang("GUI_QUICK_PHRASE_NEXT", "Next")
        )
        cursorY += pagerH
    }

    ; etxt is intentionally multiline and full width so Enter inserts
    ; real line breaks instead of accepting the dialog.
    etxtControl := ""
    if etxtName != "" {
        etxtLabelY := cursorY + 8
        etxtEditY := etxtLabelY + etxtLabelH + LABEL_GAP

        etxtEdit := myGui.Add(
            "Edit",
            "x16"
            " y" etxtEditY
            " w" CONTENT_WIDTH
            " h" tier.etxtH
            " VScroll"
            " WantReturn "
            ThemeHelper.GetEditOptions(),
            ""
        )

        ThemeHelper.StyleEdit(etxtEdit)

        etxtLabel.Move(16, etxtLabelY)
        cursorY := etxtEditY + tier.etxtH

        etxtControl := {
            name: etxtName,
            edit: etxtEdit
        }

        controls.Push(etxtControl)
    }

    previewLabelY := cursorY + SECTION_GAP
    previewEditY := previewLabelY + previewLabelHeight + LABEL_GAP

    previewLabel.Move(16, previewLabelY)

    preview := myGui.Add(
        "Edit",
        "x16"
        " y" previewEditY
        " w" CONTENT_WIDTH
        " h" tier.previewH
        " ReadOnly"
        " VScroll"
        " Wrap "
        ThemeHelper.GetEditOptions(),
        phrase.content
    )

    ThemeHelper.StyleEdit(preview)

    buttonY := previewEditY + tier.previewH + BOTTOM_GAP

    okBtn := ThemeHelper.AddButton(
        myGui,
        "Default w90 x456 y" buttonY,
        Lang("GUI_OK", "OK"),
        "primary"
    )

    cancelBtn := ThemeHelper.AddButton(
        myGui,
        "x+8 yp w90",
        Lang("GUI_CANCEL", "Cancel")
    )

    RefreshPreview(*) {
        values := Map()

        for item in controls
            values[item.name] := item.edit.Text

        preview.Value := QuickPhraseApplyVariables(
            phrase.content,
            values
        )
    }

    Accept(*) {

        if result.ok
            return true

        values := Map()

        for item in controls
            values[item.name] := item.edit.Text

        rendered := QuickPhraseRenderTemplate(
            phrase.content,
            values
        )
        result.text := rendered.text
        result.cursorOffset := rendered.cursorOffset

        result.cancelled := false
        result.ok := true

        try myGui.Hide()

        return true
    }

    Cancel(*) {

        if result.ok
            return true

        result.cancelled := true

        try myGui.Hide()

        return true
    }

    ; Paging keeps every input usable when the list does not fit at once; the
    ; values of controls on other pages are preserved because the controls
    ; themselves stay alive, only their visibility changes.
    showPage := 1

    ApplyPage() {
        for index, label in variableLabels
            label.Visible := (variablePages[index] == showPage)

        for index, editControl in variableEdits
            editControl.Visible := (variablePages[index] == showPage)

        if IsObject(pagerLabel)
            pagerLabel.Value := Lang(
                "GUI_QUICK_PHRASE_VARIABLE_PAGE",
                "Page {1} of {2}",
                showPage,
                pageCount
            )

        if IsObject(prevBtn) {
            prevBtn.Enabled := showPage > 1
            nextBtn.Enabled := showPage < pageCount
        }
    }

    GoToPage(target) {
        if (target < 1 || target > pageCount || target == showPage)
            return

        showPage := target
        ApplyPage()

        for index, editControl in variableEdits {
            if (variablePages[index] == target) {
                editControl.Focus()
                break
            }
        }
    }

    PrevPage(*) {
        GoToPage(showPage - 1)
    }

    NextPage(*) {
        GoToPage(showPage + 1)
    }

    for item in controls
        item.edit.OnEvent(
            "Change",
            RefreshPreview
        )

    okBtn.OnEvent(
        "Click",
        Accept
    )

    cancelBtn.OnEvent(
        "Click",
        Cancel
    )

    if paginate {
        prevBtn.OnEvent("Click", PrevPage)
        nextBtn.OnEvent("Click", NextPage)
    }

    myGui.OnEvent(
        "Escape",
        Cancel
    )

    myGui.OnEvent(
        "Close",
        Cancel
    )

    ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
    AppState.QuickPhraseVariableGui := myGui

    ApplyPage()

    ; Gui.Show() activates the variable-input window.
    ; The original external target is restored only by the final paste path.
    okBtn.GetPos(&okBtnX, &okBtnY, &okBtnWidth, &okBtnHeight)
    totalHeight := okBtnY + okBtnHeight + BOTTOM_MARGIN
    if (totalHeight > availableH)
        totalHeight := availableH

    myGui.Show("w680 h" totalHeight)

    if (
        variables.Length > 0
        && StrLower(Trim(variables[1])) == "etxt"
        && IsObject(etxtControl)
    ) {
        etxtControl.edit.Focus()
    } else if controls.Length > 0 {
        controls[1].edit.Focus()
    }

    RefreshPreview()

    while !result.ok && !result.cancelled
        Sleep(10)

    QuickPhraseDestroyVariableDialog(myGui)

    return result
}

QuickPhraseGetExternalTarget(targetOverride := "") {
    if IsObject(targetOverride)
        return targetOverride

    target := AppState.QuickPhraseExternalTarget
    return IsObject(target) ? target : ""
}

QuickPhraseIsInternalWindow(hwnd) {
    if !hwnd
        return true

    if hwnd == A_ScriptHwnd
        return true

    try {
        if WinGetPID("ahk_id " hwnd) == ProcessExist()
            return true
    } catch {
    }

    if IsObject(AppState.QuickPhraseGui) {
        try {
            if AppState.QuickPhraseGui.Hwnd == hwnd
                return true
        }
    }

    if IsObject(AppState.QuickPhraseVariableGui) {
        try {
            if AppState.QuickPhraseVariableGui.Hwnd == hwnd
                return true
        }
    }

    if IsObject(AppState.QuickPhraseManagerGui) {
        try {
            if AppState.QuickPhraseManagerGui.Hwnd == hwnd
                return true
        }
    }

    if IsSet(CustomMenu) {
        try {
            if CustomMenu.menuHwnd == hwnd
                return true
        }
    }

    if IsObject(AppState.FullHistoryGui) {
        try {
            if AppState.FullHistoryGui.Hwnd == hwnd
                return true
        }
    }

    if IsObject(AppState.SettingsGui) {
        try {
            if AppState.SettingsGui.Hwnd == hwnd
                return true
        }
    }

    return false
}

QuickPhraseActivateCapturedTarget(target) {
    if !IsObject(target) || !target.window
        return false

    windowHwnd := target.window

    if QuickPhraseIsInternalWindow(windowHwnd)
        return false

    if !WinExist("ahk_id " windowHwnd)
        return false

    if WinExist("A") != windowHwnd {
        try
            WinActivate("ahk_id " windowHwnd)
        catch
            return false

        if !WinWaitActive("ahk_id " windowHwnd, , 1)
            return false
    }

    return true
}

QuickPhrasePasteText(text, targetOverride := "", cursorOffset := -1) {
    target := QuickPhraseGetExternalTarget(targetOverride)

    if !IsObject(target) || !target.window
        return false

    if QuickPhraseIsInternalWindow(target.window)
        return false

    if !WinExist("ahk_id " target.window)
        return false

    try {
        ; The top-level window is only the outer destination. For the
        ; parameterized workflow, the important state is the actual child
        ; window that owned keyboard focus before Quick Phrase opened.
        ; Do not restrict this to a hard-coded class list: Chromium/Electron
        ; and other custom editors may expose a non-standard focus HWND.
        if (
            target.HasProp("control")
            && target.control
            && WinExist("ahk_id " target.control)
        ) {
            QuickPhraseRestoreCapturedControl(target)
        }

        if !PasteAsPlainText(text, "", target.window)
            return false

        if cursorOffset >= 0 {
            suffix := SubStr(text, cursorOffset + 1)
            moveCount := QuickPhraseCountCursorMoves(suffix)
            if moveCount > 0
                Send("{Left " moveCount "}")
        }

        return true
    } catch {
        return false
    }
}

QuickPhraseCountCursorMoves(text) {
    ; Count extended grapheme clusters so CRLF and supplementary Unicode use one caret step.
    count := 0
    pos := 1
    while RegExMatch(text, "\X", &match, pos) {
        count += 1
        pos := match.Pos + match.Len
    }
    return count
}

QuickPhraseRestoreCapturedControl(target) {
    if !IsObject(target)
        return false

    if !target.HasProp("window") || !target.window
        return false

    if !target.HasProp("control") || !target.control
        return false

    windowHwnd := target.window
    controlHwnd := target.control

    if !WinExist("ahk_id " windowHwnd)
        return false

    if !WinExist("ahk_id " controlHwnd)
        return false

    try {
        rootHwnd := DllCall(
            "GetAncestor",
            "Ptr",
            controlHwnd,
            "UInt",
            2,
            "Ptr"
        )

        if rootHwnd != windowHwnd
            return false

        if WinExist("A") != windowHwnd {
            WinActivate("ahk_id " windowHwnd)

            if !WinWaitActive(
                "ahk_id " windowHwnd,
                ,
                1
            ) {
                return false
            }
        }

        targetThreadId := DllCall(
            "GetWindowThreadProcessId",
            "Ptr",
            windowHwnd,
            "UInt",
            0
        )

        controlThreadId := DllCall(
            "GetWindowThreadProcessId",
            "Ptr",
            controlHwnd,
            "UInt",
            0
        )

        currentThreadId := DllCall(
            "GetCurrentThreadId"
        )

        if !targetThreadId || !controlThreadId
            return false

        attached := false

        try {
            if (
                currentThreadId != controlThreadId
                && !DllCall(
                    "AttachThreadInput",
                    "UInt",
                    currentThreadId,
                    "UInt",
                    controlThreadId,
                    "Int",
                    true
                )
            ) {
                return false
            }

            attached := currentThreadId != controlThreadId

            ; SetFocus() returns the previous focus HWND, not a
            ; success flag. A zero return is valid when there was no
            ; previously focused window, so success is determined solely by
            ; the subsequent GetGUIThreadInfo verification.
            DllCall(
                "SetFocus",
                "Ptr",
                controlHwnd,
                "Ptr"
            )

            Sleep(30)

            info := Buffer(
                A_PtrSize == 8 ? 72 : 48,
                0
            )

            NumPut(
                "UInt",
                info.Size,
                info,
                0
            )

            if !DllCall(
                "GetGUIThreadInfo",
                "UInt",
                targetThreadId,
                "Ptr",
                info.Ptr,
                "Int"
            ) {
                return false
            }

            focusOffset := A_PtrSize == 8 ? 16 : 12

            return NumGet(
                info,
                focusOffset,
                "Ptr"
            ) == controlHwnd
        } finally {
            if attached {
                DllCall(
                    "AttachThreadInput",
                    "UInt",
                    currentThreadId,
                    "UInt",
                    controlThreadId,
                    "Int",
                    false
                )
            }
        }
    } catch {
        return false
    }
}
ToggleQuickPhraseEnabled(*) {
    AppState.QuickPhraseEnabled := !AppState.QuickPhraseEnabled
    ConfigManager.Save()

    if (
        !AppState.QuickPhraseEnabled
        && IsObject(AppState.QuickPhraseGui)
        && !AppState.QuickPhraseTransactionActive
    ) {
        CloseQuickPhraseSelector(AppState.QuickPhraseGui)
    }

    key := AppState.QuickPhraseEnabled ? "MSG_QUICK_PHRASE_ENABLED" : "MSG_QUICK_PHRASE_DISABLED"
    ShowToolTip(Lang(key), 1800)
}

ShowQuickPhraseManager(returnToSelector := false) {
    if IsObject(AppState.QuickPhraseManagerGui) {
        try {
            AppState.QuickPhraseManagerGui.ReturnToSelector := returnToSelector
            WinActivate("ahk_id " AppState.QuickPhraseManagerGui.Hwnd)
            QuickPhraseRefreshManager(AppState.QuickPhraseManagerGui)
            return
        } catch {
            AppState.QuickPhraseManagerGui := ""
        }
    }

    myGui := Gui("+Resize +MinSize720x470", Lang("GUI_QUICK_PHRASE_MANAGER_TITLE", "Quick Phrase Manager"))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, Lang("GUI_QUICK_PHRASE_MANAGER_TITLE", "Quick Phrase Manager"), 700)
    ThemeHelper.AddSubtitle(
        myGui,
        Lang("GUI_QUICK_PHRASE_MANAGER_SUBTITLE", "Create, edit, reorder, categorize, and delete local quick phrases."),
        700
    )
    ThemeHelper.AddSeparator(myGui, 700)

    search := myGui.Add("Edit", "w470 r1 y+12 xm " ThemeHelper.GetEditOptions(), "")
    ThemeHelper.StyleEdit(search)
    groupOptions := QuickPhraseCategoryOptions()
    groupFilter := myGui.Add("DropDownList", "x+10 yp w220 Choose1 c" Theme.Text " Background" Theme.Control, groupOptions)
    ThemeHelper.StyleComboBox(groupFilter)
    list := myGui.Add(
        "ListView",
        "w700 r14 y+10 xm -Multi " ThemeHelper.GetLVOptions(),
        ["ID", Lang("GUI_QUICK_PHRASE_COL_NAME", "Name"), Lang("GUI_QUICK_PHRASE_COL_CATEGORY", "Category"), Lang("GUI_QUICK_PHRASE_COL_PREVIEW", "Preview")]
    )
    list.ModifyCol(1, 0)
    list.ModifyCol(2, 190)
    list.ModifyCol(3, 130)
    list.ModifyCol(4, 340)
    ThemeHelper.StyleListView(list)

    newBtn := ThemeHelper.AddButton(myGui, "Default w100 y+12 xm", "＋ " Lang("GUI_QUICK_PHRASE_NEW", "New"), "primary")
    editBtn := ThemeHelper.AddButton(myGui, "x+8 yp w100", Lang("GUI_QUICK_PHRASE_EDIT", "Edit"))
    delBtn := ThemeHelper.AddButton(myGui, "x+8 yp w100", Lang("GUI_QUICK_PHRASE_DELETE", "Delete"), "danger")
    upBtn := ThemeHelper.AddButton(myGui, "x+8 yp w105", "↑ " Lang("GUI_QUICK_PHRASE_MOVE_UP", "Move Up"))
    downBtn := ThemeHelper.AddButton(myGui, "x+8 yp w105", "↓ " Lang("GUI_QUICK_PHRASE_MOVE_DOWN", "Move Down"))
    exportBtn := ThemeHelper.AddButton(myGui, "xm y+8 w105", "⇧ " Lang("GUI_QUICK_PHRASE_EXPORT", "Export"))
    importBtn := ThemeHelper.AddButton(myGui, "x+8 yp w105", "⇩ " Lang("GUI_QUICK_PHRASE_IMPORT", "Import"))
    closeBtn := ThemeHelper.AddButton(myGui, "x+8 yp w90", Lang("GUI_FULL_CLOSE", "Close"))

    myGui.SearchBox := search
    myGui.GroupFilter := groupFilter
    myGui.GroupFilterOptionCount := groupOptions.Length
    myGui.ListView := list
    myGui.ReturnToSelector := returnToSelector
    search.OnEvent("Change", (*) => QuickPhraseRefreshManager(myGui))
    groupFilter.OnEvent("Change", (*) => QuickPhraseGroupFilterChanged(myGui))
    list.OnEvent("DoubleClick", (*) => QuickPhraseEditSelected(myGui))
    newBtn.OnEvent("Click", (*) => QuickPhraseCreateNew())
    editBtn.OnEvent("Click", (*) => QuickPhraseEditSelected(myGui))
    delBtn.OnEvent("Click", (*) => QuickPhraseDeleteSelected(myGui))
    upBtn.OnEvent("Click", (*) => QuickPhraseMoveSelected(myGui, -1))
    downBtn.OnEvent("Click", (*) => QuickPhraseMoveSelected(myGui, 1))
    exportBtn.OnEvent("Click", (*) => QuickPhraseExport())
    importBtn.OnEvent("Click", (*) => QuickPhraseImport(myGui))
    closeBtn.OnEvent("Click", (*) => CloseQuickPhraseManager(myGui))
    myGui.OnEvent("Escape", (*) => CloseQuickPhraseManager(myGui))
    myGui.OnEvent("Close", (*) => CloseQuickPhraseManager(myGui))
    AppState.QuickPhraseManagerGui := myGui
    ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
    myGui.Show("w740 h590")
    search.Focus()
    QuickPhraseRefreshManager(myGui)
}

QuickPhraseExport() {
    path := FileSelect(
        "S",
        A_ScriptDir "\QuickPhrases.json",
        Lang("GUI_QUICK_PHRASE_EXPORT", "Export Quick Phrases"),
        "JSON files (*.json)"
    )
    if path == ""
        return

    if !QuickPhraseStore.ExportToFile(path) {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_EXPORT_FAILED", "Failed to export quick phrases."), 2000)
        return
    }
    ShowToolTip(Lang("MSG_QUICK_PHRASE_EXPORTED", "Quick phrases exported."), 1500)
}

QuickPhraseImport(myGui) {
    path := FileSelect(
        "1",
        ,
        Lang("GUI_QUICK_PHRASE_IMPORT", "Import Quick Phrases"),
        "JSON files (*.json)"
    )
    if path == ""
        return

    if !DarkInputDialog.Confirm(
        Lang("CONFIRM_QUICK_PHRASE_IMPORT", "Importing will replace the current quick phrases. Continue?"),
        Lang("GUI_QUICK_PHRASE_IMPORT", "Import Quick Phrases"),
        myGui
    )
        return

    if !QuickPhraseStore.ImportFromFile(path) {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_IMPORT_FAILED", "Failed to import quick phrases."), 2200)
        return
    }
    QuickPhraseRefreshGroupFilter(myGui)
    QuickPhraseRefreshManager(myGui)
    ShowToolTip(Lang("MSG_QUICK_PHRASE_IMPORTED", "Quick phrases imported."), 1500)
}

CloseQuickPhraseManager(myGui) {
    if !IsObject(myGui)
        return

    returnToSelector := myGui.HasProp("ReturnToSelector") && myGui.ReturnToSelector
    AppState.QuickPhraseManagerGui := ""
    try myGui.Destroy()

    if !returnToSelector
        return
    ShowQuickPhraseSelector()
}

QuickPhraseRefreshManager(myGui) {
    QuickPhraseRefreshList(myGui, 105, true)
}

QuickPhraseRefreshOpenViews() {
    manager := AppState.QuickPhraseManagerGui
    if IsObject(manager) {
        try QuickPhraseRefreshGroupFilter(manager)
        try QuickPhraseRefreshManager(manager)
    }

    selector := AppState.QuickPhraseGui
    if IsObject(selector) {
        try QuickPhraseRefreshGroupFilter(selector)
        try QuickPhraseRefreshSelector(selector)
    }
}

QuickPhraseRefreshGroupFilter(myGui) {
    if !IsObject(myGui) || !myGui.HasProp("GroupFilter")
        return
    if myGui.HasProp("RefreshingGroupFilter") && myGui.RefreshingGroupFilter
        return

    groupFilter := myGui.GroupFilter
    if !IsObject(groupFilter)
        return

    myGui.RefreshingGroupFilter := true
    try {
        selectedIndexBeforeRefresh := groupFilter.Value
        selectedGroup := Trim(groupFilter.Text)
        options := QuickPhraseCategoryOptions()
        Loop myGui.GroupFilterOptionCount
            groupFilter.Delete(1)
        groupFilter.Add(options)
        myGui.GroupFilterOptionCount := options.Length

        selectedIndex := 1
        if selectedIndexBeforeRefresh > 1 {
            for index, option in options {
                if index < 2
                    continue
                if StrCompare(option, selectedGroup, false) == 0 {
                    selectedIndex := index
                    break
                }
            }
        }
        groupFilter.Choose(selectedIndex)
    } finally {
        myGui.RefreshingGroupFilter := false
    }
}
QuickPhraseSelectedPhrase(myGui) {
    row := myGui.ListView.GetNext(0, "Focused")
    if !row
        row := myGui.ListView.GetNext(0)
    if !row
        return ""

    idText := myGui.ListView.GetText(row, 1)
    return (idText ~= "^\d+$") ? QuickPhraseStore.GetById(Integer(idText)) : ""
}

QuickPhraseCreateNew() {
    ShowQuickPhraseEditor()
}

QuickPhraseEditSelected(myGui) {
    phrase := QuickPhraseSelectedPhrase(myGui)
    if !IsObject(phrase) {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_SELECT", "Please select a quick phrase."), 1500)
        return
    }

    ShowQuickPhraseEditor(phrase.id)
}

QuickPhraseDeleteSelected(myGui) {
    phrase := QuickPhraseSelectedPhrase(myGui)
    if !IsObject(phrase) {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_SELECT", "Please select a quick phrase."), 1500)
        return
    }

    if !DarkInputDialog.Confirm(
        Lang("CONFIRM_QUICK_PHRASE_DELETE", 'Delete quick phrase "{1}"?', phrase.name),
        Lang("MSG_CONFIRM", "Please confirm"),
        myGui
    )
        return

    if !QuickPhraseStore.Delete(phrase.id)
        return

    ShowToolTip(Lang("MSG_QUICK_PHRASE_DELETED", "Quick phrase deleted."), 1300)
}

QuickPhraseMoveSelected(myGui, direction) {
    phrase := QuickPhraseSelectedPhrase(myGui)
    if !IsObject(phrase)
        return

    QuickPhraseStore.Move(phrase.id, direction)
}

ShowQuickPhraseEditor(id := 0) {
    isEdit := id != 0
    phrase := isEdit ? QuickPhraseStore.GetById(id) : ""
    if isEdit && !IsObject(phrase)
        return false

    result := false
    titleKey := isEdit ? "GUI_QUICK_PHRASE_EDITOR_EDIT" : "GUI_QUICK_PHRASE_EDITOR_NEW"
    titleDefault := isEdit ? "Edit Quick Phrase" : "New Quick Phrase"

    ownerOption := IsObject(AppState.QuickPhraseManagerGui)
        ? " +Owner" AppState.QuickPhraseManagerGui.Hwnd
        : ""
    myGui := Gui(ownerOption " -MaximizeBox -MinimizeBox", Lang(titleKey, titleDefault))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, Lang(titleKey, titleDefault), 640)
    ThemeHelper.AddSeparator(myGui, 640)

    myGui.SetFont("s9 c" Theme.TextSecondary, ThemeHelper.ReadingStack())
    myGui.Add("Text", "w640 y+10", Lang("GUI_QUICK_PHRASE_NAME", "Name"))
    myGui.SetFont("s10 c" Theme.Text, ThemeHelper.ReadingStack())
    nameEdit := myGui.Add("Edit", "w640 r1 y+6 " ThemeHelper.GetEditOptions(), isEdit ? phrase.name : "")
    ThemeHelper.StyleEdit(nameEdit)

    myGui.SetFont("s9 c" Theme.TextSecondary, ThemeHelper.ReadingStack())
    myGui.Add("Text", "w640 y+12", Lang("GUI_QUICK_PHRASE_CATEGORY", "Category"))
    myGui.SetFont("s10 c" Theme.Text, ThemeHelper.ReadingStack())
    categoryEdit := myGui.Add("Edit", "w640 r1 y+6 " ThemeHelper.GetEditOptions(), isEdit ? phrase.category : "")
    ThemeHelper.StyleEdit(categoryEdit)

    myGui.SetFont("s9 c" Theme.TextSecondary, ThemeHelper.ReadingStack())
    myGui.Add("Text", "w640 y+12", Lang("GUI_QUICK_PHRASE_TEMPLATE", "Template"))
    myGui.SetFont("s10 c" Theme.Text, ThemeHelper.ReadingStack())
    contentEdit := myGui.Add("Edit", "w640 r12 y+6 " ThemeHelper.GetEditOptions(), isEdit ? phrase.content : "")
    ThemeHelper.StyleEdit(contentEdit)

    myGui.SetFont("s9 c" Theme.TextSecondary, ThemeHelper.ReadingStack())
    myGui.Add(
        "Text",
        "w640 y+8",
        Lang("GUI_QUICK_PHRASE_SYNTAX", "Use {{name}} for a variable. Repeated names are requested once.")
    )

    saveBtn := ThemeHelper.AddButton(myGui, "Default w100 y+14", Lang("GUI_QUICK_PHRASE_SAVE", "Save"), "primary")
    cancelBtn := ThemeHelper.AddButton(myGui, "x+8 yp w100", Lang("GUI_CANCEL", "Cancel"))

    Save(*) {
        name := Trim(nameEdit.Text)
        content := contentEdit.Text
        if name == "" {
            ShowToolTip(Lang("MSG_QUICK_PHRASE_NAME_REQUIRED", "Please enter a phrase name."), 1600)
            nameEdit.Focus()
            return
        }
        if content == "" {
            ShowToolTip(Lang("MSG_QUICK_PHRASE_CONTENT_REQUIRED", "Please enter template content."), 1600)
            contentEdit.Focus()
            return
        }

        category := Trim(categoryEdit.Text)
        ok := isEdit
            ? QuickPhraseStore.Update(id, name, category, content)
            : QuickPhraseStore.Create(name, category, content)

        if !ok {
            ShowToolTip(Lang("MSG_QUICK_PHRASE_SAVE_FAILED", "Failed to save quick phrase."), 2000)
            return
        }

        result := true
        myGui.Destroy()
        ShowToolTip(Lang("MSG_QUICK_PHRASE_SAVED", "Quick phrase saved."), 1300)
    }

    Cancel(*) => myGui.Destroy()

    saveBtn.OnEvent("Click", Save)
    cancelBtn.OnEvent("Click", Cancel)
    myGui.OnEvent("Escape", Cancel)
    myGui.OnEvent("Close", Cancel)

    ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
    myGui.Show("w680 h560")
    nameEdit.Focus()
    WinWaitClose("ahk_id " myGui.Hwnd)
    return result
}
