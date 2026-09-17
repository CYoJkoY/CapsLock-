#Requires AutoHotkey v2.0

; Resolve the real source window of the clipboard text.
; History already stores the window title captured at copy
; time, so prefer a history match first.
; Fall back to the current active window title otherwise.
_ResolveClipboardSource(text) {
    ; Only scan recent entries to keep the lookup fast
    scanCount := Min(AppState.History.Length, 20)
    Loop scanCount {
        item := AppState.History[A_Index]
        if item["text"] == text
            return item["source"]
    }
    try {
        sourceTitle := WinGetTitle("A")
    } catch {
        sourceTitle := "Unknown Window"
    }
    return sourceTitle != "" ? sourceTitle : "Unknown Window"
}

PasteWithCurrentMode() {
    CapturePasteTarget()

    target := A_Clipboard
    if target == "" {
        ShowToolTip(Lang("MSG_CLIPBOARD_EMPTY"), 2000)
        return
    }

    ; Classify each line without destroying the original text.
    ; Trimming is used for path detection only, never for the
    ; content that will be pasted, so indentation and blank
    ; lines of plain text survive untouched.
    lines := StrSplit(target, "`n", "`r")
    validLines := []
    allImages := true
    hasPaths := false
    sawContent := false
    for line in lines {
        trimmed := Trim(line)
        if trimmed == ""
            continue
        sawContent := true
        if FileExist(trimmed) {
            hasPaths := true
            ; Drop only paths matched by ignore rules
            if FileHelper.ShouldIgnore(trimmed)
                continue
        }
        validLines.Push(trimmed)
        if allImages && (!FileExist(trimmed) || !PathDetector.IsImageExtension(trimmed))
            allImages := false
    }
    if !sawContent {
        ShowToolTip(Lang("MSG_CLIPBOARD_EMPTY"), 2000)
        return
    }
    if hasPaths && validLines.Length == 0 {
        ShowToolTip(Lang("MSG_ALL_PATHS_IGNORED"), 2000)
        return
    }
    if allImages && AppState.ImageMagickExe && FileExist(AppState.ImageMagickExe) {
        original := A_Clipboard
        AppState.IgnoreNextClipChange := true
        A_Clipboard := Join(validLines, "`n")
        pdfPath := ProcessImagePathsToPDF()
    
        AppState.IgnoreNextClipChange := true
        A_Clipboard := original

        if pdfPath != ""
            PasteFile(pdfPath, "pdf")
        else
            ShowToolTip(Lang("MSG_IMAGE_PDF_FAIL"), 2000)

        return
    }

    ; Plain text (no file or folder path in the clipboard).
    ;
    ; File mode used to always write a temp file and drop it on the target,
    ; which does nothing at all when the target only accepts text (and gave
    ; no feedback either). Handle the plain-text case explicitly:
    ;   - text mode  -> paste as text (with the source header)
    ;   - file mode  -> temp file, unless the focused control can only
    ;                   receive text, then fall back to a text paste
    ; Both branches report what happened through the OSD.
    if !hasPaths {
        item := Map(
            "text", target,
            "source", _ResolveClipboardSource(target),
            "time", FormatTime(, "yyyy-MM-dd HH:mm:ss")
        )

        if AppState.PasteMode == 2
            HandlePlainText(item)
        else if _PasteTargetIsTextInput()
            PasteAsPlainText(target, Lang("MSG_PASTE_FALLBACK_TEXT"))
        else
            PasteTempText("; " _GetHistorySourceInfo(item) "`n`n" target, Lang("MSG_PASTE_AS_FILE"))

        return
    }

    ; Rebuild the text only when it is a file/folder path list.
    ; Plain text is forwarded verbatim (original clipboard),
    ; which preserves indentation and empty lines exactly.
    newTarget := Join(validLines, "`n")
    item := Map(
        "text", newTarget,
        "source", _ResolveClipboardSource(target),
        "time", FormatTime(, "yyyy-MM-dd HH:mm:ss")
    )

    PasteAsFile(item)
}

; Heuristic for "this target cannot receive a file drop".
; A CF_HDROP paste is silently ignored by plain text controls (Notepad,
; classic edit fields, ...), so those targets get a text paste instead.
_PasteTargetIsTextInput() {
    try
        classNN := ControlGetFocus("A")
    catch
        return false

    if classNN == ""
        return false

    className := RegExReplace(classNN, "\d+$")

    for name in AppState.TextInputControls {
        if className == name
            return true
    }

    return false
}
