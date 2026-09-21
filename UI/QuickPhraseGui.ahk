#Requires AutoHotkey v2.0

ShowQuickPhraseSelector(captureTarget := true) {
    if captureTarget {
        target := WinExist("A")
        if target
            AppState.TargetWindow := target
    }

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

    myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", Lang("GUI_QUICK_PHRASE_TITLE", "Quick Phrases"))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, "💬 " Lang("GUI_QUICK_PHRASE_TITLE", "Quick Phrases"), 640)
    ThemeHelper.AddSubtitle(
        myGui,
        Lang("GUI_QUICK_PHRASE_SUBTITLE", "Search by name or content. Press Enter or double-click to insert."),
        640
    )
    ThemeHelper.AddSeparator(myGui, 640)

    search := myGui.Add("Edit", "w640 r1 y+12 " ThemeHelper.GetEditOptions(), "")
    ThemeHelper.StyleEdit(search)
    list := myGui.Add(
        "ListView",
        "w640 r12 y+10 -Multi " ThemeHelper.GetLVOptions(),
        ["ID", Lang("GUI_QUICK_PHRASE_COL_NAME", "Name"), Lang("GUI_QUICK_PHRASE_COL_CATEGORY", "Category"), Lang("GUI_QUICK_PHRASE_COL_PREVIEW", "Preview")]
    )
    list.ModifyCol(1, 0)
    list.ModifyCol(2, 190)
    list.ModifyCol(3, 120)
    list.ModifyCol(4, 330)
    ThemeHelper.StyleListView(list)

    status := myGui.Add("Text", "w640 y+8", "")
    useBtn := ThemeHelper.AddButton(myGui, "Default w110 y+12", "✓ " Lang("GUI_QUICK_PHRASE_USE", "Use"), "primary")
    manageBtn := ThemeHelper.AddButton(myGui, "x+8 yp w110", "📝 " Lang("GUI_QUICK_PHRASE_MANAGE", "Manage"))
    closeBtn := ThemeHelper.AddButton(myGui, "x+8 yp w90", Lang("GUI_FULL_CLOSE", "Close"))

    myGui.SearchBox := search
    myGui.ListView := list
    myGui.Status := status
    myGui.OnEvent("Escape", (*) => CloseQuickPhraseSelector(myGui))
    myGui.OnEvent("Close", (*) => CloseQuickPhraseSelector(myGui))
    search.OnEvent("Change", (*) => QuickPhraseRefreshSelector(myGui))
    useBtn.OnEvent("Click", (*) => QuickPhraseUseSelected(myGui))
    list.OnEvent("DoubleClick", (*) => QuickPhraseUseSelected(myGui))
    manageBtn.OnEvent("Click", (*) => QuickPhraseOpenManager(myGui))
    closeBtn.OnEvent("Click", (*) => CloseQuickPhraseSelector(myGui))

    AppState.QuickPhraseGui := myGui
    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
    myGui.Show("w680 h470")
    search.Focus()
    QuickPhraseRefreshSelector(myGui)
}

CloseQuickPhraseSelector(myGui) {
    try myGui.Destroy()
    AppState.QuickPhraseGui := ""
    if !IsObject(AppState.QuickPhraseManagerGui)
        AppState.TargetWindow := 0
}

QuickPhraseOpenManager(selectorGui) {
    try selectorGui.Hide()
    ShowQuickPhraseManager(true)
}

QuickPhraseRefreshSelector(myGui) {
    if !IsObject(myGui) || !IsObject(myGui.ListView)
        return

    list := myGui.ListView
    filter := StrLower(Trim(myGui.SearchBox.Text))
    list.Delete()
    count := 0

    for phrase in QuickPhraseStore.GetAll() {
        if filter != "" && !InStr(StrLower(phrase.name " " phrase.content), filter)
            continue
        list.Add(, phrase.id, phrase.name, phrase.category, QuickPhrasePreview(phrase.content, 100))
        count += 1
    }

    total := QuickPhraseStore.GetAll().Length
    if total == 0
        myGui.Status.Text := Lang("GUI_QUICK_PHRASE_EMPTY", "No saved quick phrases. Use Manage to create one.")
    else
        myGui.Status.Text := Lang("GUI_QUICK_PHRASE_STATUS", "{1} quick phrase(s) available.", count)
}

QuickPhraseUseSelected(myGui) {
    row := myGui.ListView.GetNext(0, "Focused")
    if !row
        row := myGui.ListView.GetNext(0)

    if !row {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_SELECT", "Please select a quick phrase."), 1500)
        return
    }

    idText := myGui.ListView.GetText(row, 1)
    if !(idText ~= "^\d+$")
        return

    phrase := QuickPhraseStore.GetById(Integer(idText))
    target := AppState.TargetWindow
    if !IsObject(phrase) || !target || !WinExist("ahk_id " target) {
        ShowToolTip(Lang("MSG_NO_TARGET", "No target window detected."), 2000)
        return
    }

    myGui.Hide()
    variables := QuickPhraseExtractVariables(phrase.content)
    if variables.Length == 0 {
        ok := QuickPhrasePasteText(phrase.content, target)
    } else {
        result := ShowQuickPhraseVariableDialog(phrase, variables)
        if !result.ok {
            myGui.Show()
            WinActivate("ahk_id " myGui.Hwnd)
            myGui.SearchBox.Focus()
            return
        }
        ok := QuickPhrasePasteText(result.text, target)
    }

    CloseQuickPhraseSelector(myGui)
    if !ok
        ShowToolTip(Lang("MSG_QUICK_PHRASE_PASTE_FAILED", "Could not insert the quick phrase."), 2200)
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
        if name != "" && !seen.Has(name) {
            variables.Push(name)
            seen[name] := true
        }
        pos := match.Pos + match.Len
    }
    return variables
}

QuickPhraseApplyVariables(template, values) {
    result := ""
    pattern := "\{\{\s*([^{}\r\n]+?)\s*\}\}"
    pos := 1

    while RegExMatch(template, pattern, &match, pos) {
        if match.Pos > pos
            result .= SubStr(template, pos, match.Pos - pos)
        name := Trim(match[1])
        result .= values.Has(name) ? values[name] : match[0]
        pos := match.Pos + match.Len
    }

    return result . SubStr(template, pos)
}

ShowQuickPhraseVariableDialog(phrase, variables) {
    result := {ok: false, text: ""}

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

    normalRows := 0
    if normalVariables.Length > 0
        normalRows := Integer((normalVariables.Length + 1) / 2)

    normalRowH := 78
    normalEditOptions := "Multi WantReturn " ThemeHelper.GetEditOptions()
    normalBottomY := 96 + normalRows * normalRowH

    if etxtName != "" {
        etxtLabelY := normalBottomY + 8
        etxtEditY := etxtLabelY + 18
        previewY := etxtEditY + 96 + 10
    } else {
        etxtLabelY := 0
        etxtEditY := 0
        previewY := 102 + normalRows * 52
    }

    myGui := Gui(
        "+AlwaysOnTop -MaximizeBox -MinimizeBox",
        Lang(
            "GUI_QUICK_PHRASE_VARIABLE_TITLE",
            "Fill phrase variables"
        )
    )

    ThemeHelper.StyleGui(myGui)

    ThemeHelper.AddTitle(
        myGui,
        "✎ " Lang(
            "GUI_QUICK_PHRASE_VARIABLE_TITLE",
            "Fill phrase variables"
        ),
        640
    )

    ThemeHelper.AddSubtitle(
        myGui,
        Lang(
            "GUI_QUICK_PHRASE_VARIABLE_HINT",
            "Fields follow first appearance order; repeated names are requested once."
        ),
        640
    )

    ThemeHelper.AddSeparator(myGui, 640)

    controls := []
    etxtControl := ""

    ; Ordinary variables stay as compact single-line controls.
    for index, name in normalVariables {
        column := index <= normalRows ? 0 : 1
        row := column ? index - normalRows : index

        x := 16 + column * 320
        y := 96 + (row - 1) * normalRowH

        myGui.SetFont(
            "s9 c" AppState.THEME_FG_DIM,
            AppState.THEME_FONT
        )

        myGui.Add(
            "Text",
            "x" x " y" y " w300",
            name
        )

        myGui.SetFont(
            "s10 c" AppState.THEME_FG,
            AppState.THEME_FONT
        )

        edit := myGui.Add(
            "Edit",
            "x" x
            " y" (y + 18)
            " w300"
            " r3 "
            normalEditOptions,
            ""
        )

        ThemeHelper.StyleEdit(edit)

        controls.Push({
            name: name,
            edit: edit
        })
    }

    ; etxt is intentionally multiline and full width so Enter inserts
    ; real line breaks instead of accepting the dialog.
    if etxtName != "" {
        myGui.SetFont(
            "s9 c" AppState.THEME_FG_DIM,
            AppState.THEME_FONT
        )

        myGui.Add(
            "Text",
            "x16 y" etxtLabelY " w640",
            etxtName
        )

        myGui.SetFont(
            "s10 c" AppState.THEME_FG,
            AppState.THEME_FONT
        )

        etxtEdit := myGui.Add(
            "Edit",
            "x16"
            " y" etxtEditY
            " w640"
            " r5"
            " VScroll"
            " WantReturn "
            ThemeHelper.GetEditOptions(),
            ""
        )

        ThemeHelper.StyleEdit(etxtEdit)

        etxtControl := {
            name: etxtName,
            edit: etxtEdit
        }

        controls.Push(etxtControl)
    }

    myGui.SetFont(
        "s9 c" AppState.THEME_FG_DIM,
        AppState.THEME_FONT
    )

    myGui.Add(
        "Text",
        "x16 y" previewY,
        Lang(
            "GUI_QUICK_PHRASE_PREVIEW",
            "Preview"
        )
    )

    preview := myGui.Add(
        "Edit",
        "x16"
        " y" (previewY + 20)
        " w640"
        " h120"
        " ReadOnly"
        " VScroll"
        " Wrap "
        ThemeHelper.GetEditOptions(),
        phrase.content
    )

    ThemeHelper.StyleEdit(preview)

    okBtn := ThemeHelper.AddButton(
        myGui,
        "Default w90 x456 y+12",
        "✓ " Lang("GUI_OK", "OK"),
        "primary"
    )

    cancelBtn := ThemeHelper.AddButton(
        myGui,
        "x+8 yp w90",
        "✕ " Lang("GUI_CANCEL", "Cancel")
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
        values := Map()

        for item in controls
            values[item.name] := item.edit.Text

        result.ok := true
        result.text := QuickPhraseApplyVariables(
            phrase.content,
            values
        )

        myGui.Destroy()
    }

    Cancel(*) {
        myGui.Destroy()
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

    myGui.OnEvent(
        "Escape",
        Cancel
    )

    myGui.OnEvent(
        "Close",
        Cancel
    )

    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)

    myGui.Show(
        "w680 h" (previewY + 185)
    )

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

    WinWaitClose(
        "ahk_id " myGui.Hwnd
    )

    return result
}

QuickPhrasePasteText(text, targetHwnd) {
    if !targetHwnd || !WinExist("ahk_id " targetHwnd)
        return false

    backup := ""

    try {
        ; Activate the destination before replacing the clipboard.
        WinActivate("ahk_id " targetHwnd)

        if !WinWaitActive(
            "ahk_id " targetHwnd,
            ,
            1
        )
            return false

        ; Preserve the original clipboard across overlapping Quick Phrase
        ; transactions. If a previous transaction is still pending and its
        ; clipboard has not changed, keep its original backup.
        currentSequence := DllCall(
            "GetClipboardSequenceNumber",
            "UInt"
        )

        if (
            AppState.QuickPhraseClipboardRestorePending
            && currentSequence == AppState.QuickPhraseClipboardSequence
            && IsObject(AppState.QuickPhraseClipboardBackup)
        ) {
            backup := AppState.QuickPhraseClipboardBackup
        } else {
            backup := ClipboardAll()
        }

        AppState.IgnoreNextClipChange := true
        A_Clipboard := text

        ; Clipboard assignment is normally synchronous, but ClipWait
        ; protects against a transient clipboard-provider delay on Windows.
        ; Throw here so the catch block restores the pre-Quick-Phrase
        ; clipboard instead of returning with temporary text still installed.
        if !ClipWait(1)
            throw Error("Quick Phrase clipboard was not ready.")

        expected := A_Clipboard
        sequence := DllCall(
            "GetClipboardSequenceNumber",
            "UInt"
        )

        AppState.QuickPhraseClipboardBackup := backup
        AppState.QuickPhraseClipboardExpected := expected
        AppState.QuickPhraseClipboardSequence := sequence

        AppState.QuickPhraseClipboardRestoreGeneration += 1
        generation := AppState.QuickPhraseClipboardRestoreGeneration
        AppState.QuickPhraseClipboardRestorePending := true

        ; Give Windows and the target application one stable message turn
        ; after activation before dispatching Ctrl+V. This matches the existing
        ; paste path used elsewhere in the application.
        Sleep(100)
        Send("^v")

        ; Do not restore the original clipboard synchronously. Some
        ; applications read clipboard data asynchronously after Ctrl+V.
        SetTimer(
            () => QuickPhraseRestoreClipboard(generation),
            -AppState.QuickPhraseClipboardRestoreDelay
        )

        return true
    } catch {
        if IsObject(backup) {
            AppState.IgnoreNextClipChange := true
            try A_Clipboard := backup
        }

        AppState.QuickPhraseClipboardRestorePending := false
        AppState.QuickPhraseClipboardBackup := ""
        AppState.QuickPhraseClipboardExpected := ""
        AppState.QuickPhraseClipboardSequence := 0

        return false
    }
}

QuickPhraseRestoreClipboard(generation) {
    if !AppState.QuickPhraseClipboardRestorePending
        return

    if generation != AppState.QuickPhraseClipboardRestoreGeneration
        return

    currentSequence := DllCall(
        "GetClipboardSequenceNumber",
        "UInt"
    )

    ; A newer clipboard mutation belongs to the user or another application.
    ; Never overwrite it with the old pre-Quick-Phrase clipboard.
    if currentSequence != AppState.QuickPhraseClipboardSequence {
        AppState.QuickPhraseClipboardRestorePending := false
        AppState.QuickPhraseClipboardBackup := ""
        AppState.QuickPhraseClipboardExpected := ""
        AppState.QuickPhraseClipboardSequence := 0
        return
    }

    if A_Clipboard != AppState.QuickPhraseClipboardExpected {
        AppState.QuickPhraseClipboardRestorePending := false
        AppState.QuickPhraseClipboardBackup := ""
        AppState.QuickPhraseClipboardExpected := ""
        AppState.QuickPhraseClipboardSequence := 0
        return
    }

    backup := AppState.QuickPhraseClipboardBackup

    AppState.IgnoreNextClipChange := true

    try {
        A_Clipboard := backup
    } catch {
        SetTimer(
            () => QuickPhraseRestoreClipboard(generation),
            -250
        )
        return
    }

    AppState.QuickPhraseClipboardRestorePending := false
    AppState.QuickPhraseClipboardBackup := ""
    AppState.QuickPhraseClipboardExpected := ""
    AppState.QuickPhraseClipboardSequence := 0
}

ToggleQuickPhraseEnabled(*) {
    AppState.QuickPhraseEnabled := !AppState.QuickPhraseEnabled
    ConfigManager.Save()

    if !AppState.QuickPhraseEnabled && IsObject(AppState.QuickPhraseGui)
        CloseQuickPhraseSelector(AppState.QuickPhraseGui)

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

    myGui := Gui("+Resize +AlwaysOnTop +MinSize720x470", Lang("GUI_QUICK_PHRASE_MANAGER_TITLE", "Quick Phrase Manager"))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, "📝 " Lang("GUI_QUICK_PHRASE_MANAGER_TITLE", "Quick Phrase Manager"), 700)
    ThemeHelper.AddSubtitle(
        myGui,
        Lang("GUI_QUICK_PHRASE_MANAGER_SUBTITLE", "Create, edit, reorder, categorize, and delete local quick phrases."),
        700
    )
    ThemeHelper.AddSeparator(myGui, 700)

    search := myGui.Add("Edit", "w700 r1 y+12 " ThemeHelper.GetEditOptions(), "")
    ThemeHelper.StyleEdit(search)
    list := myGui.Add(
        "ListView",
        "w700 r14 y+10 -Multi " ThemeHelper.GetLVOptions(),
        ["ID", Lang("GUI_QUICK_PHRASE_COL_NAME", "Name"), Lang("GUI_QUICK_PHRASE_COL_CATEGORY", "Category"), Lang("GUI_QUICK_PHRASE_COL_PREVIEW", "Preview")]
    )
    list.ModifyCol(1, 0)
    list.ModifyCol(2, 190)
    list.ModifyCol(3, 130)
    list.ModifyCol(4, 340)
    ThemeHelper.StyleListView(list)

    newBtn := ThemeHelper.AddButton(myGui, "Default w100 y+12", "＋ " Lang("GUI_QUICK_PHRASE_NEW", "New"), "primary")
    editBtn := ThemeHelper.AddButton(myGui, "x+8 yp w100", "✎ " Lang("GUI_QUICK_PHRASE_EDIT", "Edit"))
    delBtn := ThemeHelper.AddButton(myGui, "x+8 yp w100", "🗑 " Lang("GUI_QUICK_PHRASE_DELETE", "Delete"), "danger")
    upBtn := ThemeHelper.AddButton(myGui, "x+8 yp w105", "↑ " Lang("GUI_QUICK_PHRASE_MOVE_UP", "Move Up"))
    downBtn := ThemeHelper.AddButton(myGui, "x+8 yp w105", "↓ " Lang("GUI_QUICK_PHRASE_MOVE_DOWN", "Move Down"))
    closeBtn := ThemeHelper.AddButton(myGui, "x+8 yp w90", Lang("GUI_FULL_CLOSE", "Close"))

    myGui.SearchBox := search
    myGui.ListView := list
    myGui.ReturnToSelector := returnToSelector
    search.OnEvent("Change", (*) => QuickPhraseRefreshManager(myGui))
    list.OnEvent("DoubleClick", (*) => QuickPhraseEditSelected(myGui))
    newBtn.OnEvent("Click", (*) => QuickPhraseCreateNew(myGui))
    editBtn.OnEvent("Click", (*) => QuickPhraseEditSelected(myGui))
    delBtn.OnEvent("Click", (*) => QuickPhraseDeleteSelected(myGui))
    upBtn.OnEvent("Click", (*) => QuickPhraseMoveSelected(myGui, -1))
    downBtn.OnEvent("Click", (*) => QuickPhraseMoveSelected(myGui, 1))
    closeBtn.OnEvent("Click", (*) => CloseQuickPhraseManager(myGui))
    myGui.OnEvent("Escape", (*) => CloseQuickPhraseManager(myGui))
    myGui.OnEvent("Close", (*) => CloseQuickPhraseManager(myGui))

    AppState.QuickPhraseManagerGui := myGui
    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
    myGui.Show("w740 h590")
    search.Focus()
    QuickPhraseRefreshManager(myGui)
}

CloseQuickPhraseManager(myGui) {
    returnToSelector := myGui.HasProp("ReturnToSelector") && myGui.ReturnToSelector
    try myGui.Destroy()
    AppState.QuickPhraseManagerGui := ""

    if returnToSelector
        ShowQuickPhraseSelector(false)
    else
        AppState.TargetWindow := 0
}

QuickPhraseRefreshManager(myGui) {
    list := myGui.ListView
    filter := StrLower(Trim(myGui.SearchBox.Text))
    list.Delete()

    for phrase in QuickPhraseStore.GetAll() {
        if filter != "" && !InStr(StrLower(phrase.name " " phrase.category " " phrase.content), filter)
            continue
        list.Add(, phrase.id, phrase.name, phrase.category, QuickPhrasePreview(phrase.content, 105))
    }

    if list.GetCount()
        list.Modify(1, "Select")
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

QuickPhraseCreateNew(myGui) {
    if ShowQuickPhraseEditor()
        QuickPhraseRefreshManager(myGui)
}

QuickPhraseEditSelected(myGui) {
    phrase := QuickPhraseSelectedPhrase(myGui)
    if !IsObject(phrase) {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_SELECT", "Please select a quick phrase."), 1500)
        return
    }
    if ShowQuickPhraseEditor(phrase.id)
        QuickPhraseRefreshManager(myGui)
}

QuickPhraseDeleteSelected(myGui) {
    phrase := QuickPhraseSelectedPhrase(myGui)
    if !IsObject(phrase) {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_SELECT", "Please select a quick phrase."), 1500)
        return
    }

    answer := MsgBox(
        Lang("CONFIRM_QUICK_PHRASE_DELETE", 'Delete quick phrase "{1}"?', phrase.name),
        Lang("MSG_CONFIRM", "Please confirm"),
        "YesNo Icon?"
    )
    if answer != "Yes"
        return

    if QuickPhraseStore.Delete(phrase.id) {
        ShowToolTip(Lang("MSG_QUICK_PHRASE_DELETED", "Quick phrase deleted."), 1300)
        QuickPhraseRefreshManager(myGui)
    }
}

QuickPhraseMoveSelected(myGui, direction) {
    phrase := QuickPhraseSelectedPhrase(myGui)
    if IsObject(phrase) && QuickPhraseStore.Move(phrase.id, direction)
        QuickPhraseRefreshManager(myGui)
}

ShowQuickPhraseEditor(id := 0) {
    isEdit := id != 0
    phrase := isEdit ? QuickPhraseStore.GetById(id) : ""
    if isEdit && !IsObject(phrase)
        return false

    result := false
    titleKey := isEdit ? "GUI_QUICK_PHRASE_EDITOR_EDIT" : "GUI_QUICK_PHRASE_EDITOR_NEW"
    titleDefault := isEdit ? "Edit Quick Phrase" : "New Quick Phrase"

    myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", Lang(titleKey, titleDefault))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, "📝 " Lang(titleKey, titleDefault), 640)
    ThemeHelper.AddSeparator(myGui, 640)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.Add("Text", "w640 y+10", Lang("GUI_QUICK_PHRASE_NAME", "Name"))
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
    nameEdit := myGui.Add("Edit", "w640 r1 y+6 " ThemeHelper.GetEditOptions(), isEdit ? phrase.name : "")
    ThemeHelper.StyleEdit(nameEdit)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.Add("Text", "w640 y+12", Lang("GUI_QUICK_PHRASE_CATEGORY", "Category"))
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
    categoryEdit := myGui.Add("Edit", "w640 r1 y+6 " ThemeHelper.GetEditOptions(), isEdit ? phrase.category : "")
    ThemeHelper.StyleEdit(categoryEdit)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.Add("Text", "w640 y+12", Lang("GUI_QUICK_PHRASE_TEMPLATE", "Template"))
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
    contentEdit := myGui.Add("Edit", "w640 r12 y+6 " ThemeHelper.GetEditOptions(), isEdit ? phrase.content : "")
    ThemeHelper.StyleEdit(contentEdit)

    myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
    myGui.Add(
        "Text",
        "w640 y+8",
        Lang("GUI_QUICK_PHRASE_SYNTAX", "Use {{name}} for a variable. Repeated names are requested once.")
    )

    saveBtn := ThemeHelper.AddButton(myGui, "Default w100 y+14", "✓ " Lang("GUI_QUICK_PHRASE_SAVE", "Save"), "primary")
    cancelBtn := ThemeHelper.AddButton(myGui, "x+8 yp w100", "✕ " Lang("GUI_CANCEL", "Cancel"))

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

    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
    myGui.Show("w680 h560")
    nameEdit.Focus()
    WinWaitClose("ahk_id " myGui.Hwnd)
    return result
}
