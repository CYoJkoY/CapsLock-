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
    currentWindow := DllCall("GetForegroundWindow", "Ptr")
    if !currentWindow || QuickPhraseIsInternalWindow(currentWindow)
        return ""

    cached := AppState.QuickPhraseLatestExternalTarget
    if IsObject(cached)
        && cached.window == currentWindow
        && A_TickCount - cached.tick <= 1500
    {
        return cached
    }

    target := QuickPhraseReadForegroundTarget()
    if !IsObject(target) || target.window != currentWindow
        return ""

    return target
}

QuickPhraseReadForegroundTarget() {
    return QuickPhraseReadThreadTarget(0, true)
}

QuickPhraseReadThreadTarget(threadId := 0, requireForeground := false) {
    infoBuffer := Buffer(A_PtrSize == 8 ? 72 : 48, 0)
    NumPut("UInt", infoBuffer.Size, infoBuffer, 0)

    if !DllCall(
        "GetGUIThreadInfo",
        "UInt", threadId,
        "Ptr", infoBuffer.Ptr,
        "Int"
    )
        return ""

    activeHwnd := NumGet(
        infoBuffer,
        8,
        "Ptr"
    )

    foregroundHwnd := DllCall("GetForegroundWindow", "Ptr")
    if requireForeground {
        if !foregroundHwnd || QuickPhraseIsInternalWindow(foregroundHwnd)
            return ""

        if activeHwnd && activeHwnd != foregroundHwnd
            return ""

        windowHwnd := foregroundHwnd
    } else {
        if !activeHwnd || QuickPhraseIsInternalWindow(activeHwnd)
            return ""

        if foregroundHwnd != activeHwnd
            return ""

        windowHwnd := activeHwnd
    }

    controlHwnd := NumGet(
        infoBuffer,
        A_PtrSize == 8 ? 16 : 12,
        "Ptr"
    )

    caretHwnd := NumGet(
        infoBuffer,
        A_PtrSize == 8 ? 48 : 28,
        "Ptr"
    )

    controlClass := ""
    if controlHwnd {
        try controlClass := WinGetClass("ahk_id " controlHwnd)
        catch
            controlClass := ""
    }

    return {
        window: windowHwnd,
        control: controlHwnd,
        caret: caretHwnd,
        controlClass: controlClass,
        tick: A_TickCount
    }
}

QuickPhraseInitializeFocusTracking() {
    if AppState.QuickPhraseFocusCallback
        return true

    try {
        AppState.QuickPhraseFocusCallback := CallbackCreate(
            QuickPhraseWinEventProc,
            "",
            7
        )

        AppState.QuickPhraseFocusForegroundHook := DllCall(
            "SetWinEventHook",
            "UInt", 0x0003,
            "UInt", 0x0003,
            "Ptr", 0,
            "Ptr", AppState.QuickPhraseFocusCallback,
            "UInt", 0,
            "UInt", 0,
            "UInt", 0x0002,
            "Ptr"
        )

        AppState.QuickPhraseFocusObjectHook := DllCall(
            "SetWinEventHook",
            "UInt", 0x8005,
            "UInt", 0x8005,
            "Ptr", 0,
            "Ptr", AppState.QuickPhraseFocusCallback,
            "UInt", 0,
            "UInt", 0,
            "UInt", 0x0002,
            "Ptr"
        )

        if !AppState.QuickPhraseFocusForegroundHook
            || !AppState.QuickPhraseFocusObjectHook
        {
            QuickPhraseShutdownFocusTracking()
            return false
        }

        target := QuickPhraseReadForegroundTarget()
        if IsObject(target)
            AppState.QuickPhraseLatestExternalTarget := target

        return true
    } catch {
        QuickPhraseShutdownFocusTracking()
        return false
    }
}

QuickPhraseShutdownFocusTracking() {
    if AppState.QuickPhraseFocusForegroundHook {
        try DllCall(
            "UnhookWinEvent",
            "Ptr", AppState.QuickPhraseFocusForegroundHook
        )
        AppState.QuickPhraseFocusForegroundHook := 0
    }

    if AppState.QuickPhraseFocusObjectHook {
        try DllCall(
            "UnhookWinEvent",
            "Ptr", AppState.QuickPhraseFocusObjectHook
        )
        AppState.QuickPhraseFocusObjectHook := 0
    }

    if AppState.QuickPhraseFocusCallback {
        try CallbackFree(AppState.QuickPhraseFocusCallback)
        AppState.QuickPhraseFocusCallback := 0
    }

    AppState.QuickPhraseLatestExternalTarget := ""
}

QuickPhraseWinEventProc(
    hook,
    event,
    hwnd,
    idObject,
    idChild,
    eventThread,
    eventTime
) {
    target := QuickPhraseReadThreadTarget(eventThread)
    if IsObject(target)
        AppState.QuickPhraseLatestExternalTarget := target
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

    QuickPhraseExecutePhrase(phrase)
    return true
}

QuickPhraseExecutePhrase(phrase) {
    reopenSelector := false
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

            ok := QuickPhrasePasteText(result.text)
        }
    } catch as caughtError {
        errorMessage := caughtError.Message
    } finally {
        AppState.QuickPhraseTransactionActive := false

        if reopenSelector {
            ShowQuickPhraseSelector()
        } else {
            AppState.QuickPhraseExternalTarget := ""
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

        result.ok := true
        result.cancelled := false

        QuickPhraseDestroyVariableDialog(myGui)

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

    ; Gui.Show() displays and activates the variable-input window.
    ; Do not issue a second WinActivate() against its HWND here: the GUI
    ; manager may still be transitioning the window, and the extra activation
    ; can raise "Target window not found" for an otherwise valid Gui object.
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

QuickPhraseNormalizeClipboardText(text) {
    normalized := StrReplace(text, "`r`n", "`n")
    normalized := StrReplace(normalized, "`r", "`n")
    return StrReplace(normalized, "`n", "`r`n")
}

QuickPhraseGetExternalTarget() {
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

    return false
}

QuickPhraseActivateCapturedTarget(windowHwnd, expectedControl := 0) {
    if !windowHwnd || QuickPhraseIsInternalWindow(windowHwnd)
        return false

    if !WinExist("ahk_id " windowHwnd)
        return false

    try
        WinActivate("ahk_id " windowHwnd)
    catch
        return false

    if WinWaitActive("ahk_id " windowHwnd, , 1) != windowHwnd
        return false

    ; Window activation and keyboard-focus restoration are separate state
    ; transitions. Do not send Ctrl+V until the foreground thread reports a
    ; focus HWND that actually belongs to the captured target window.
    deadline := A_TickCount + 500

    while true {
        state := QuickPhraseReadForegroundTarget()

        if IsObject(state) && state.window == windowHwnd && state.control {
            if expectedControl && state.control == expectedControl
                return true

            rootHwnd := DllCall(
                "GetAncestor",
                "Ptr", state.control,
                "UInt", 2,
                "Ptr"
            )

            if rootHwnd == windowHwnd
                return true
        }

        if A_TickCount >= deadline
            return false

        Sleep(10)
    }
}

QuickPhrasePasteText(text) {
    target := QuickPhraseGetExternalTarget()
    if !IsObject(target)
        return false

    if !target.window || !WinExist("ahk_id " target.window)
        return false

    if target.control
        && WinExist("ahk_id " target.control)
        && QuickPhraseIsTextInputControl(target.controlClass)
    {
        try {
            EditPaste(
                QuickPhraseNormalizeClipboardText(text),
                target.control
            )
            return true
        } catch {
        }
    }

    backup := ""
    try
        backup := ClipboardAll()
    catch
        return false

    expectedText := QuickPhraseNormalizeClipboardText(text)
    expectedSequence := 0
    clipboardPrepared := false

    try {
        AppState.IgnoreNextClipChange := true
        A_Clipboard := expectedText

        expectedSequence := DllCall(
            "GetClipboardSequenceNumber",
            "UInt"
        )
        clipboardPrepared := true

        if !ClipWait(1)
            throw Error("Quick Phrase clipboard was not ready.")

        if !QuickPhraseActivateCapturedTarget(target.window, target.control)
            return false

        SendEvent("^v")
        Sleep(120)
        return true
    } catch {
        return false
    } finally {
        if clipboardPrepared {
            QuickPhraseScheduleClipboardRestore(
                backup,
                expectedText,
                expectedSequence
            )
        }
    }
}

QuickPhraseScheduleClipboardRestore(backup, expectedText, expectedSequence) {
    AppState.QuickPhraseClipboardBackup := backup
    AppState.QuickPhraseClipboardExpected := expectedText
    AppState.QuickPhraseClipboardSequence := expectedSequence
    AppState.QuickPhraseClipboardRestorePending := true

    SetTimer(
        QuickPhraseRestoreClipboard,
        -750
    )
}

QuickPhraseRestoreClipboard() {
    if !AppState.QuickPhraseClipboardRestorePending
        return

    AppState.QuickPhraseClipboardRestorePending := false

    backup := AppState.QuickPhraseClipboardBackup
    expectedText := AppState.QuickPhraseClipboardExpected
    expectedSequence := AppState.QuickPhraseClipboardSequence

    AppState.QuickPhraseClipboardBackup := ""
    AppState.QuickPhraseClipboardExpected := ""
    AppState.QuickPhraseClipboardSequence := 0

    currentSequence := DllCall(
        "GetClipboardSequenceNumber",
        "UInt"
    )

    if currentSequence != expectedSequence
        return

    if A_Clipboard != expectedText
        return

    AppState.IgnoreNextClipChange := true
    try A_Clipboard := backup
}

QuickPhraseIsTextInputControl(controlClass) {
    if controlClass == ""
        return false

    normalized := StrLower(controlClass)

    for knownClass in AppState.TextInputControls {
        known := StrLower(knownClass)
        if normalized == known
            return true
    }

    return false
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
