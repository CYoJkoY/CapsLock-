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
            paths.Push(line)
        }
    }

    if (paths.Length == 0) {
        ShowToolTip(Lang("MSG_NO_IMAGE_FILES", "No image files were found in the clipboard."), 2000)
        return ""
    }

    progressGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    ThemeHelper.StyleGui(progressGui)
    ThemeHelper.AddTitle(progressGui, "⏳ " Lang("MSG_PROCESSING_TITLE", "Creating PDF"), 360)
    ThemeHelper.AddSubtitle(progressGui, Lang("MSG_PROCESSING_SUBTITLE", "Please wait..."), 360)
    progressGui.Add("Text", "x16 y+8 w340 center c" AppState.THEME_FG_DIM, Lang("MSG_PROCESSING_WAIT", "Processing images..."))
    progressGui.Show("AutoSize Center")
    ThemeHelper.ApplyImmersiveDarkMode(progressGui.Hwnd)

    outputPdf := A_Temp "\ClipTemp_" A_TickCount ".pdf"
    logFile := A_Temp "\CapsLock_ImageMagick_" A_TickCount ".log"
    errorText := ""

    success := _RunImageMagickPdf(exe, paths, outputPdf, logFile)

    ; ImageMagick Windows builds may deny PDF writes through policy.xml.
    ; Detect that specific failure and add a user-level write-only PDF rule.
    if !success {
        try if FileExist(logFile)
            errorText := FileRead(logFile, "UTF-8")

        if _IsImageMagickPdfPolicyError(errorText) {
            if _EnableUserPdfWritePolicy() {
                success := _RunImageMagickPdf(exe, paths, outputPdf, logFile)
                try if FileExist(logFile)
                    errorText := FileRead(logFile, "UTF-8")
            }
        }
    }

    try progressGui.Destroy()
    try if FileExist(logFile)
        FileDelete(logFile)

    if !success {
        if FileExist(outputPdf)
            try FileDelete(outputPdf)

        detail := _TrimExternalError(errorText)
        if detail != "" {
            MsgBox(
                Lang("MSG_IMAGEMAGICK_FAILED_DETAIL", "", "ImageMagick could not create the PDF.`n`n{1}`n`nCheck the ImageMagick installation and PDF security policy.", detail),
                Lang("MSG_ERROR", "ImageMagick Error"),
                "Iconx"
            )
        } else {
            MsgBox(
                Lang("MSG_IMAGEMAGICK_FAILED", "ImageMagick could not create the PDF. Check the selected executable and its PDF support."),
                Lang("MSG_ERROR", "ImageMagick Error"),
                "Iconx"
            )
        }
        return ""
    }

    if !FileExist(outputPdf) {
        MsgBox(Lang("MSG_PDF_IM_NO_OUTPUT", "ImageMagick finished without creating the PDF output."), Lang("MSG_ERROR"), "Iconx")
        return ""
    }

    try {
        if FileGetSize(outputPdf) <= 0 {
            FileDelete(outputPdf)
            MsgBox(Lang("MSG_PDF_IM_EMPTY_OUTPUT", "ImageMagick created an empty PDF output."), Lang("MSG_ERROR"), "Iconx")
            return ""
        }
    } catch as err {
        try FileDelete(outputPdf)
        MsgBox(Lang("MSG_PDF_IM_EXCEPTION", "", err.Message), Lang("MSG_ERROR"), "Iconx")
        return ""
    }

    ShowToolTip(Lang("MSG_IMAGE_PDF_SUCCESS", "Images converted to PDF."), 2000)
    return outputPdf
}

_RunImageMagickPdf(exe, paths, outputPdf, logFile) {
    try if FileExist(logFile)
        FileDelete(logFile)

    pathArgs := ""
    for path in paths
        pathArgs .= '"' path '" '

    ; Keep read-affecting options before input files and quote every path.
    commandLine := '"' exe '" -density 150 -auto-orient -quality 95 ' . pathArgs . '"' outputPdf '"'

    ; Use a temporary batch file solely to capture stdout/stderr. This makes
    ; ImageMagick's real diagnostic visible instead of reducing every failure
    ; to the unhelpful generic "exit code 1" message.
    batchPath := A_Temp "\CapsLock_ImageMagick_" A_TickCount "_" A_MSec ".cmd"
    batch := "@echo off`r`n"
    batch .= commandLine " > " '"' logFile '"' " 2>&1`r`n"
    batch .= "exit /b %errorlevel%`r`n"

    FileAppend(batch, batchPath, "UTF-8")
    exitCode := RunWait('"' A_ComSpec '" /d /c call "' batchPath '"', , "Hide")

    try FileDelete(batchPath)

    return exitCode == 0 && FileExist(outputPdf) && FileGetSize(outputPdf) > 0
}

_IsImageMagickPdfPolicyError(errorText) {
    if (errorText == "")
        return false
    normalized := StrLower(errorText)
    return InStr(normalized, "security policy") && InStr(normalized, "pdf")
}

_EnableUserPdfWritePolicy() {
    try {
        userProfile := EnvGet("USERPROFILE")
        if (userProfile == "")
            return false

        configDir := userProfile "\.config\ImageMagick"
        policyPath := configDir "\policy.xml"
        backupPath := policyPath ".capslock-backup"
        DirCreate(configDir)

        if FileExist(policyPath) {
            content := FileRead(policyPath, "UTF-8")
            if !FileExist(backupPath)
                FileCopy(policyPath, backupPath, false)
        } else {
            content := "<?xml version=""1.0"" encoding=""UTF-8""?>`r`n<policymap>`r`n</policymap>`r`n"
        }

        if InStr(content, "CapsLock- PDF write access")
            return true

        insertion := "  <!-- CapsLock- PDF write access: required for image-to-PDF conversion. -->`r`n"
            . "  <policy domain=""module"" rights=""write"" pattern=""PDF"" />`r`n"
            . "  <policy domain=""coder"" rights=""write"" pattern=""PDF"" />`r`n"

        closeTag := "</policymap>"
        closePos := InStr(content, closeTag)
        if !closePos
            return false

        newContent := SubStr(content, 1, closePos - 1) . insertion . SubStr(content, closePos)
        FileDelete(policyPath)
        FileAppend(newContent, policyPath, "UTF-8")
        return true
    } catch {
        return false
    }
}

_TrimExternalError(text) {
    text := Trim(text)
    if (text == "")
        return ""

    lines := StrSplit(text, "`n", "`r")
    result := ""
    count := 0
    for line in lines {
        line := Trim(line)
        if (line == "")
            continue
        if result != ""
            result .= "`n"
        result .= line
        count++
        if count >= 8
            break
    }
    return result
}
