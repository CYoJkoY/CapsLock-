#Requires AutoHotkey v2.0

; -----------------------------------------------------------------------------
; Public entry point – called by hotkey.
; -----------------------------------------------------------------------------
ConvertWithPandoc() {
    CapturePasteTarget()

    text := A_Clipboard
    if (text == "") {
        ShowToolTip(Lang("MSG_CLIPBOARD_EMPTY", "Clipboard is empty"), 2000)
        return
    }

    settings := _ValidatePandocSettings()
    if (settings[1] == "" || settings[2] == "")
        return
    pandoc := settings[1], outFormat := settings[2]

    files := _CollectInputFiles(text)
    if (files.Length == 0) {
        ShowToolTip(Lang("MSG_NO_FILES_FOUND", "No valid files or folders found in clipboard"), 2000)
        return
    }

    filtered := _FilterIgnoredFiles(files)
    if (filtered.Length == 0) {
        ShowToolTip(Lang("MSG_ALL_FILES_IGNORED", "All files are ignored"), 2000)
        return
    }

    result := _RunPandocConversions(filtered, pandoc, outFormat)
    _HandleConversionResult(result[1], result[2], result[3])
}

; -----------------------------------------------------------------------------
; Validate Pandoc path and output format.
; Returns [exePath, format] or ["", ""] on failure.
; -----------------------------------------------------------------------------
_ValidatePandocSettings() {
    pandoc := AppState.PandocExe
    if (pandoc == "" || !FileExist(pandoc)) {
        ShowToolTip(Lang("MSG_PANDOC_NOT_FOUND", "Pandoc executable not found. Please set path in settings."), 3000)
        return ["", ""]
    }

    outFormat := AppState.PandocOutputFormat
    if (!_IsOutputFormatSupported(outFormat)) {
        ShowToolTip(Lang("MSG_PANDOC_INVALID_OUTPUT", "Invalid output format: {1}", outFormat), 2500)
        return ["", ""]
    }

    return [pandoc, outFormat]
}

; -----------------------------------------------------------------------------
; Parse clipboard content and collect all valid file/folder paths.
; -----------------------------------------------------------------------------
_CollectInputText(text) {
    allPaths := []
    lines := StrSplit(text, "`n", "`r")
    Loop lines.Length {
        line := Trim(lines[A_Index])
        if (line != "" && FileExist(line))
            allPaths.Push(line)
    }
    return allPaths
}

; -----------------------------------------------------------------------------
; Expand folders recursively into individual file paths.
; -----------------------------------------------------------------------------
_ExpandFolders(allPaths) {
    final := []
    Loop allPaths.Length {
        path := allPaths[A_Index]
        if (InStr(FileExist(path), "D")) {
            collected := FileHelper.CollectFilesFromFolder(path, true)
            Loop collected.Length
                final.Push(collected[A_Index])
        } else {
            final.Push(path)
        }
    }
    return final
}

; -----------------------------------------------------------------------------
; Combine parsing + expansion into one step.
; -----------------------------------------------------------------------------
_CollectInputFiles(text) {
    all := _CollectInputText(text)
    if (all.Length == 0)
        return []
    return _ExpandFolders(all)
}

; -----------------------------------------------------------------------------
; Filter out paths that match ignore patterns.
; -----------------------------------------------------------------------------
_FilterIgnoredFiles(files) {
    filtered := []
    Loop files.Length {
        f := files[A_Index]
        if (!FileHelper.ShouldIgnore(f))
            filtered.Push(f)
    }
    return filtered
}

; -----------------------------------------------------------------------------
; Run Pandoc on each file, return [outputFiles, skippedFiles, failedCount].
; -----------------------------------------------------------------------------
_RunPandocConversions(files, pandoc, outFormat) {
    total := files.Length
    showProgress := (total > 1)
    progressGui := ""
    progressText := ""
    progressBar := ""

    if (showProgress) {
        pg := _CreateProgressGui()
        progressGui := pg.Gui
        progressText := pg.TextCtrl
        progressBar := pg.BarCtrl
    }

    outputFiles := []
    skippedFiles := []
    failedCount := 0

    Loop files.Length {
        idx := A_Index
        inFile := files[idx]

        if (showProgress) {
            SplitPath(inFile, &fileName)
            progressText.Text := Lang("MSG_PANDOC_PROGRESS", "Converting {1}/{2}: {3}", idx, total, fileName)
            progressBar.Value := (idx / total) * 100
        }

        inFormat := _DetectInputFormat(inFile)
        if (inFormat == "") {
            skippedFiles.Push(inFile)
            continue
        }

        outFile := _BuildOutputPath(inFile, outFormat)
        if (outFile == "") {
            failedCount++
            continue
        }

        cmd := '"' pandoc '" -f ' inFormat ' -t ' outFormat ' -o "' outFile '" "' inFile '"'
        try {
            RunWait(cmd, , "Hide")
            if (FileExist(outFile))
                outputFiles.Push(outFile)
            else
                failedCount++
        } catch {
            failedCount++
        }
    }

    if (showProgress)
        try progressGui.Destroy()

    return [outputFiles, skippedFiles, failedCount]
}

; -----------------------------------------------------------------------------
; Build the progress GUI, return an object with Gui, TextCtrl, BarCtrl.
; -----------------------------------------------------------------------------
_CreateProgressGui() {
    progress_gui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    ThemeHelper.StyleGui(progress_gui)
    ThemeHelper.AddTitle(progress_gui, "⏳ " Lang("MSG_PANDOC_PROGRESS_TITLE", "Converting Files"), 420)
    ThemeHelper.AddSubtitle(progress_gui, Lang("MSG_PANDOC_PROGRESS_SUBTITLE", "Please wait..."), 420)
    progress_gui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
    textCtrl := progress_gui.Add("Text", "x16 y+8 w380 center", "")
    barCtrl := progress_gui.Add("Progress", "x16 y+8 w380 h20 c" AppState.THEME_ACCENT " Background" AppState.THEME_CONTROL_BG, 0)
    progress_gui.Show("AutoSize Center")
    ThemeHelper.ApplyImmersiveDarkMode(progress_gui.Hwnd)
    return { Gui: progress_gui, TextCtrl: textCtrl, BarCtrl: barCtrl }
}

; -----------------------------------------------------------------------------
; Handle final results: show skip info, paste outputs, schedule cleanup.
; -----------------------------------------------------------------------------
_HandleConversionResult(outputFiles, skippedFiles, failedCount) {
    if (skippedFiles.Length > 0) {
        skippedMsg := Lang("MSG_PANDOC_SKIPPED_FILES", "Skipped unsupported files:`n{1}", Join(skippedFiles, "`n"))
        ShowToolTip(skippedMsg, 3000)
    }

    if (outputFiles.Length == 0) {
        ShowToolTip(Lang("MSG_PANDOC_NO_OUTPUT", "No files were converted successfully"), 2000)
        return
    }

    ClipboardHelper.SetClipboardFiles(outputFiles)
    ActivateAndPaste()

    Loop outputFiles.Length {
        CleanupManager.ScheduleDeletion(outputFiles[A_Index])
    }

    ShowToolTip(Lang("MSG_PANDOC_SUCCESS", "Converted {1} file(s)", outputFiles.Length), 2000)
}
