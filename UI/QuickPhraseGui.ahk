#Requires AutoHotkey v2.0

; AppState is provided by the root script's Config\\Globals.ahk include.
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

    myGui := Gui(
        "+AlwaysOnTop -MaximizeBox -MinimizeBox",
        Lang("GUI_QUICK_PHRASE_TITLE", "Quick Phrases")
    )
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

QuickPhraseRefreshSelector(myGui) {
    if !IsObject(myGui) || !IsObject(myGui.ListView)
        return

    list := myGui.ListView
    filter := StrLower(Trim(myGui.SearchBox.Text))
    list.Delete()
    count := 0
    phrases := []

    for phrase in QuickPhraseStore.GetAll() {
        if filter != "" && !InStr(StrLower(phrase.name " " phrase.category " " phrase.content), filter)
            continue
        phrases.Push(phrase)
    }

    QuickPhraseSortSelectorPhrases(phrases)

    for phrase in phrases {
        list.Add(, phrase.id, phrase.name, phrase.category, QuickPhrasePreview(phrase.content, 100))
        count += 1
    }

    total := QuickPhraseStore.GetAll().Length
    if total == 0
        myGui.Status.Text := Lang("GUI_QUICK_PHRASE_EMPTY", "No saved quick phrases. Use Manage to create one.")
    else
        myGui.Status.Text := Lang("GUI_QUICK_PHRASE_STATUS", "{1} quick phrase(s) available.", count)
}

QuickPhraseSortSelectorPhrases(phrases) {
    n := phrases.Length
    if n <= 1
        return

    Loop n - 1 {
        limit := n - A_Index
        Loop limit {
            index := A_Index
            left := phrases[index]
            right := phrases[index + 1]

            if QuickPhraseCompareSelectorPhrases(left, right) > 0 {
                phrases[index] := right
                phrases[index + 1] := left
            }
        }
    }
}

QuickPhraseCompareSelectorPhrases(left, right) {
    leftCategory := Trim(left.category)
    rightCategory := Trim(right.category)

    if leftCategory == "" && rightCategory != ""
        return 1
    if leftCategory != "" && rightCategory == ""
        return -1

    categoryCompare := StrCompare(leftCategory, rightCategory, false)
    if categoryCompare != 0
        return categoryCompare

    if left.order != right.order
        return left.order < right.order ? -1 : 1

    nameCompare := StrCompare(left.name, right.name, false)
    if nameCompare != 0
        return nameCompare

    if left.id == right.id
        return 0

    return left.id < right.id ? -1 : 1
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
    deferredTransaction := false
    ok := false
    errorMessage := ""

    try {
        variables := QuickPhraseExtractVariables(phrase.content)

        if variables.Length == 0 {
            ok := QuickPhrasePasteText(phrase.content)
        } else {
            result := ShowQuickPhraseVariableDialog(
                phrase,
                variables
            )

            if !result.ok {
                reopenSelector := result.cancelled
                return
            }

            ; The variable dialog owns the rest of this transaction after OK.
            ; Its finalizer will paste, destroy the GUI, and release the target.
            if result.HasProp("pending") && result.pending {
                deferredTransaction := true
                return
            }

            ok := result.HasProp("pasteOk") ? result.pasteOk : false
        }
    } catch as caughtError {
        errorMessage := caughtError.Message
    } finally {
        if !deferredTransaction {
            AppState.QuickPhraseTransactionActive := false

            if reopenSelector {
                ShowQuickPhraseSelector()
            } else {
                AppState.QuickPhraseExternalTarget := ""
            }
        }
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

    normalRows := 0
    if normalVariables.Length > 0
        normalRows := Integer((normalVariables.Length + 1) / 2)

    normalRowH := 78
    ; Every variable can contain structured/multiline text (for example YAML).
    ; Keep the compact two-column layout, but make each input a true multiline
    ; Edit control so pasted line breaks are preserved.
    normalEditOptions := "Multi WantReturn VScroll " ThemeHelper.GetEditOptions()
    normalBottomY := 96 + normalRows * normalRowH

    if etxtName != "" {
        etxtLabelY := normalBottomY + 8
        etxtEditY := etxtLabelY + 18
        previewY := etxtEditY + 96 + 10
    } else {
        etxtLabelY := 0
        etxtEditY := 0
        previewY := 102 + normalRows * normalRowH
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

    ; Ordinary variables stay compact while supporting multiline input.
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

        editControl := myGui.Add(
            "Edit",
            "x" x
            " y" (y + 18)
            " w300"
            " r3 "
            normalEditOptions,
            ""
        )

        ThemeHelper.StyleEdit(editControl)

        controls.Push({
            name: name,
            edit: editControl
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

        if result.ok
            return true

        values := Map()

        for item in controls
            values[item.name] := item.edit.Text

        result.text := QuickPhraseApplyVariables(
            phrase.content,
            values
        )

        result.cancelled := false
        result.ok := true
        result.pending := true

        target := QuickPhraseGetExternalTarget()

        ; The OK callback only commits the completed text. It must not end the
        ; transaction or perform the paste itself. A fresh script thread owns
        ; the final delivery and cleanup.
        try myGui.Hide()

        delivery := {
            result: result,
            text: result.text,
            target: target,
            gui: myGui
        }

        SetTimer(
            QuickPhraseFinalizeVariablePhrase.Bind(delivery),
            -1
        )

        return true
    }

    Cancel(*) {

        if result.ok
            return true

        result.cancelled := true

        QuickPhraseDestroyVariableDialog(myGui)

        return true
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
    AppState.QuickPhraseVariableGui := myGui

    ; Gui.Show() activates the variable-input window.
    ; The original external target is restored only by the final paste path.
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

QuickPhraseGetExternalTarget(targetOverride := "") {
    if IsObject(targetOverride)
        return targetOverride

    target := AppState.QuickPhraseExternalTarget
    return IsObject(target) ? target : ""
}

QuickPhraseFinalizeVariablePhrase(delivery) {
    ok := false

    try {
        if (
            IsObject(delivery)
            && delivery.HasProp("target")
            && IsObject(delivery.target)
            && delivery.target.window
        ) {
            ok := QuickPhrasePasteText(
                delivery.text,
                delivery.target
            )
        }
    } catch {
        ok := false
    } finally {
        if IsObject(delivery) && delivery.HasProp("result") {
            delivery.result.pasteOk := ok
            delivery.result.pending := false
        }

        if IsObject(delivery) && delivery.HasProp("gui")
            QuickPhraseDestroyVariableDialog(delivery.gui)

        ; The async variable transaction owns its own cleanup. The outer
        ; QuickPhraseExecutePhrase() deliberately does not touch these fields
        ; while pending=true.
        AppState.QuickPhraseTransactionActive := false
        AppState.QuickPhraseExternalTarget := ""
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

QuickPhrasePasteText(text, targetOverride := "") {
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

        return PasteAsPlainText(text, "", target.window)
    } catch {
        return false
    }
}

QuickPhraseRestoreCapturedControl(target) {
    if !IsObject(target)
        return false

    if !target.HasProp("window") || !target.window
        return false

    if !target.HasProp("control") || !target.control
        return false

    if !WinExist("ahk_id " target.window)
        return false

    if !WinExist("ahk_id " target.control)
        return false

    try {
        if WinExist("A") != target.window {
            WinActivate("ahk_id " target.window)

            if !WinWaitActive("ahk_id " target.window, , 1)
                return false
        }

        ControlFocus(
            target.control,
            "ahk_id " target.window
        )

        Sleep(30)

        try {
            focusedControl := ControlGetFocus(
                "ahk_id " target.window
            )

            if focusedControl == target.control
                return true

            ; ControlGetFocus may return a class/NN string rather than the
            ; exact HWND on some applications. A successful ControlFocus is
            ; still useful in that case, so do not reject it solely on this
            ; verification result.
            return true
        } catch {
            return true
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
        ShowQuickPhraseSelector()
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
