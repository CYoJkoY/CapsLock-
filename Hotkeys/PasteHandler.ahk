#Requires AutoHotkey v2.0

PasteWithCurrentMode() {
    CapturePasteTarget()

    target := A_Clipboard
    if target == "" {
        ShowToolTip(Lang("MSG_CLIPBOARD_EMPTY"), 2000)
        return
    }

    lines := StrSplit(target, "`n", "`r")
    validLines := []
    allImages := true

    for line in lines {
        line := Trim(line)
        if line == ""
            continue

        if FileExist(line) && FileHelper.ShouldIgnore(line)
            continue

        validLines.Push(line)

        if allImages && (!FileExist(line) || !PathDetector.IsImageExtension(line))
            allImages := false
    }

    if validLines.Length == 0 {
        ShowToolTip(Lang("MSG_CLIPBOARD_EMPTY"), 2000)
        return
    }

    newTarget := Join(validLines, "`n")

    if allImages && AppState.ImageMagickExe && FileExist(AppState.ImageMagickExe) {
        original := A_Clipboard
        AppState.IgnoreNextClipChange := true
        A_Clipboard := newTarget

        pdfPath := ProcessImagePathsToPDF()

        AppState.IgnoreNextClipChange := true
        A_Clipboard := original

        if pdfPath != ""
            PasteFile(pdfPath, "pdf")
        else
            ShowToolTip(Lang("MSG_IMAGE_PDF_FAIL"), 2000)

        return
    }

    item := Map(
        "text", newTarget,
        "source", "Direct Paste",
        "time", FormatTime(, "yyyy-MM-dd HH:mm:ss")
    )

    PasteAsFile(item)
}
