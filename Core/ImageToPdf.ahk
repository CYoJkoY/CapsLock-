#Requires AutoHotkey v2.0

ProcessImagePathsToPDF() {
    exe := Trim(AppState.ImageMagickExe)
    if (exe == "" || !FileExist(exe)) {
        MsgBox(Lang("MSG_IMAGEMAGICK_ERROR", "", "ImageMagick executable is not configured or no longer exists."), Lang("MSG_ERROR"), "Iconx")
        return ""
    }

    paths := []
    lines := StrSplit(A_Clipboard, "`n", "`r")
    for line in lines {
        line := Trim(line)
        if (line == "")
            continue

        exists := FileExist(line)
        if (exists && !InStr(exists, "D")) {
            if FileHelper.ShouldIgnore(line)
                continue

            paths.Push('"' line '"')
        }
    }

    if (paths.Length == 0) {
        ShowToolTip(Lang("MSG_NO_IMAGE_FILES"), 2000)
        return ""
    }

    progressGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    ThemeHelper.StyleGui(progressGui)
    ThemeHelper.AddTitle(progressGui, "⏳ " Lang("MSG_PROCESSING_TITLE", ""), 320)
    ThemeHelper.AddSubtitle(progressGui, Lang("MSG_PROCESSING_SUBTITLE", ""), 320)
    progressGui.Add("Text", "x16 y+8 w300 center c" AppState.THEME_FG_DIM, Lang("MSG_PROCESSING_WAIT"))
    progressGui.Show("AutoSize Center")
    ThemeHelper.ApplyImmersiveDarkMode(progressGui.Hwnd)

    outputPdf := A_Temp "\ClipTemp_" A_TickCount ".pdf"

    ; ImageMagick 7 uses `magick.exe` as its main CLI entry point.
    ; Keep read-affecting options before the input files and explicitly set
    ; the PDF output format. This also produces one PDF containing all input images.
    cmd := '"' exe '" -density 150 -auto-orient -quality 95 ' . Join(paths, " ") . ' "' outputPdf '"'

    exitCode := ""
    guiDestroyed := false
    try {
        exitCode := RunWait(cmd, , "Hide")
    } catch as err {
        try progressGui.Destroy()
        ShowToolTip(Lang("MSG_PDF_IM_EXCEPTION", "", err.Message), 4000)
        return ""
    }

    try {
        progressGui.Destroy()
        guiDestroyed := true
    }

    if (exitCode != 0) {
        if FileExist(outputPdf)
            try FileDelete(outputPdf)

        MsgBox(
            Lang("MSG_PDF_IM_EXIT_CODE", "ImageMagick failed with exit code {1}.", exitCode),
            Lang("MSG_ERROR"),
            "Iconx"
        )
        return ""
    }

    if !FileExist(outputPdf) {
        MsgBox(
            Lang("MSG_PDF_IM_NO_OUTPUT", "ImageMagick finished without creating the PDF output."),
            Lang("MSG_ERROR"),
            "Iconx"
        )
        return ""
    }

    if (FileGetSize(outputPdf) <= 0) {
        try FileDelete(outputPdf)
        MsgBox(
            Lang("MSG_PDF_IM_EMPTY_OUTPUT", "ImageMagick created an empty PDF output."),
            Lang("MSG_ERROR"),
            "Iconx"
        )
        return ""
    }

    ShowToolTip(Lang("MSG_IMAGE_PDF_SUCCESS"), 2000)
    return outputPdf
}
