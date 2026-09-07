#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Convert files using Pandoc and paste the result
; ---------------------------------------------------------------------------
ConvertWithPandoc() {
    CapturePasteTarget()

    ; 1. Get raw text from clipboard
    text := A_Clipboard
    if (text == "") {
        ShowToolTip(Lang("MSG_CLIPBOARD_EMPTY", "Clipboard is empty"), 2000)
        return
    }

    ; 2. Parse all valid paths (files and folders)
    allPaths := []
    lines := StrSplit(text, "`n", "`r")
    for line in lines {
        line := Trim(line)
        if (line == "")
            continue
        if FileExist(line)
            allPaths.Push(line)
    }
    if (allPaths.Length == 0) {
        ShowToolTip(Lang("MSG_NO_FILES_FOUND", "No valid files or folders found in clipboard"), 2000)
        return
    }

    ; 3. Expand folders into individual files (recursive)
    finalFiles := []
    for path in allPaths {
        if InStr(FileExist(path), "D") {
            collected := FileHelper.CollectFilesFromFolder(path, true)
            for f in collected
                finalFiles.Push(f)
        } else {
            finalFiles.Push(path)
        }
    }

    ; 4. Apply ignore patterns
    filteredFiles := []
    for f in finalFiles {
        if !FileHelper.ShouldIgnore(f)
            filteredFiles.Push(f)
    }
    if (filteredFiles.Length == 0) {
        ShowToolTip(Lang("MSG_ALL_FILES_IGNORED", "All files are ignored"), 2000)
        return
    }

    ; 5. Validate Pandoc executable
    pandoc := Trim(AppState.PandocExe)
    if (pandoc == "" || !FileExist(pandoc)) {
        ShowToolTip(Lang("MSG_PANDOC_NOT_FOUND", "Pandoc executable not found. Please set path in settings."), 3000)
        return
    }

    ; 6. Validate output format
    outFormat := StrLower(Trim(AppState.PandocOutputFormat))
    if (!_IsOutputFormatSupported(outFormat)) {
        ShowToolTip(Lang("MSG_PANDOC_INVALID_OUTPUT", "Invalid output format: {1}", outFormat), 2500)
        return
    }

    ; 7. Prepare progress GUI (if more than 1 file)
    total := filteredFiles.Length
    showProgress := (total > 1)
    progressGui := ""
    progressText := ""
    progressBar := ""
    if showProgress {
        progressGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        ThemeHelper.StyleGui(progressGui)
        ThemeHelper.AddTitle(progressGui, "⏳ " Lang("MSG_PANDOC_PROGRESS_TITLE", "Converting Files"), 420)
        ThemeHelper.AddSubtitle(progressGui, Lang("MSG_PANDOC_PROGRESS_SUBTITLE", "Please wait..."), 420)
        progressGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        progressText := progressGui.Add("Text", "x16 y+8 w380 center", "")
        progressBar := progressGui.Add("Progress", "x16 y+8 w380 h20 c" AppState.THEME_ACCENT " Background" AppState.THEME_CONTROL_BG, 0)
        progressGui.Show("AutoSize Center")
        ThemeHelper.ApplyImmersiveDarkMode(progressGui.Hwnd)
    }

    ; 8. Convert each file
    outputFiles := []
    skippedFiles := []
    failedFiles := []

    for idx, inFile in filteredFiles {
        if showProgress {
            SplitPath(inFile, &fileName)
            progressText.Text := Lang("MSG_PANDOC_PROGRESS", "Converting {1}/{2}: {3}", idx, total, fileName)
            progressBar.Value := (idx / total) * 100
        }

        ; Detect input format from the source extension.
        inFormat := _DetectInputFormat(inFile)
        if (inFormat == "") {
            skippedFiles.Push(inFile)
            continue
        }

        outFile := _BuildOutputPath(inFile, outFormat, idx)
        if (outFile == "") {
            failedFiles.Push(inFile)
            continue
        }

        ; Let Pandoc infer the writer from the output filename. This avoids
        ; format-name mismatches and follows Pandoc's normal CLI behavior.
        ; -s is required for complete document formats such as HTML/RTF/ICML.
        cmd := '"' pandoc '" --from=' inFormat ' --standalone --output="' outFile '" "' inFile '"'

        try {
            exitCode := RunWait(cmd, , "Hide")
            if (exitCode == 0 && FileExist(outFile) && FileGetSize(outFile) > 0)
                outputFiles.Push(outFile)
            else
                failedFiles.Push(inFile " [exit code " exitCode "]")
        } catch as err {
            failedFiles.Push(inFile " [" err.Message "]")
        }
    }

    if showProgress {
        try progressGui.Destroy()
    }

    if (skippedFiles.Length > 0) {
        skippedMsg := Lang("MSG_PANDOC_SKIPPED_FILES", "Skipped unsupported files:`n{1}", Join(skippedFiles, "`n"))
        ShowToolTip(skippedMsg, 3500)
    }

    if (failedFiles.Length > 0) {
        failedMsg := Lang("MSG_PANDOC_FAILED_FILES", "Pandoc failed for:`n{1}", Join(failedFiles, "`n"))
        MsgBox(failedMsg, Lang("MSG_ERROR"), "Iconx")
    }

    if (outputFiles.Length == 0) {
        ShowToolTip(Lang("MSG_PANDOC_NO_OUTPUT", "No files were converted successfully"), 2500)
        return
    }

    ClipboardHelper.SetClipboardFiles(outputFiles)
    ActivateAndPaste()

    for f in outputFiles
        CleanupManager.ScheduleDeletion(f)

    ShowToolTip(Lang("MSG_PANDOC_SUCCESS", "Converted {1} file(s)", outputFiles.Length), 2000)
}

; ---------------------------------------------------------------------------
; Detect input format from file extension.
; ---------------------------------------------------------------------------
_DetectInputFormat(filePath) {
    try {
        SplitPath(filePath, , , &ext)
    } catch {
        return ""
    }

    ext := StrLower(Trim(ext))
    if (ext == "")
        return ""

    for fmt in AppState.PandocInputFormats {
        if (fmt == ext)
            return fmt
    }

    static extMap := Map(
        "adoc", "asciidoc",
        "asciidoc", "asciidoc",
        "bib", "bibtex",
        "md", "markdown",
        "mkd", "markdown",
        "mdown", "markdown",
        "markdown", "markdown",
        "html", "html",
        "htm", "html",
        "tex", "latex",
        "latex", "latex",
        "rst", "rst",
        "rtf", "rtf",
        "odt", "odt",
        "epub", "epub",
        "ipynb", "ipynb",
        "mediawiki", "mediawiki",
        "org", "org",
        "textile", "textile",
        "t2t", "t2t",
        "csv", "csv",
        "tsv", "tsv",
        "json", "json",
        "xml", "xml",
        "docx", "docx",
        "pptx", "pptx",
        "xlsx", "xlsx",
        "jats", "jats",
        "jira", "jira",
        "ris", "ris",
        "pod", "pod",
        "man", "man",
        "mdoc", "mdoc",
        "muse", "muse",
        "native", "native",
        "opml", "opml",
        "typst", "typst",
        "vimwiki", "vimwiki",
        "djot", "djot",
        "creole", "creole",
        "dokuwiki", "dokuwiki",
        "gfm", "gfm",
        "haddock", "haddock",
        "commonmark", "commonmark"
    )

    try {
        if extMap.Has(ext)
            return extMap[ext]
    }
    return ""
}

; ---------------------------------------------------------------------------
; Build a unique temporary output path.
; ---------------------------------------------------------------------------
_BuildOutputPath(inFile, outFormat, index := 1) {
    try {
        SplitPath(inFile, &name, &dir, &ext, &nameNoExt)
    } catch {
        return ""
    }

    static extMap := Map(
        "docx", "docx",
        "html", "html",
        "markdown", "md",
        "latex", "tex",
        "pdf", "pdf",
        "rst", "rst",
        "rtf", "rtf",
        "odt", "odt",
        "epub", "epub",
        "ipynb", "ipynb",
        "mediawiki", "mediawiki",
        "org", "org",
        "textile", "textile",
        "t2t", "t2t",
        "csv", "csv",
        "tsv", "tsv",
        "json", "json",
        "xml", "xml",
        "pptx", "pptx",
        "xlsx", "xlsx",
        "jats", "jats",
        "jira", "jira",
        "ris", "ris",
        "pod", "pod",
        "man", "man",
        "mdoc", "mdoc",
        "muse", "muse",
        "native", "native",
        "opml", "opml",
        "typst", "typst",
        "vimwiki", "vimwiki",
        "djot", "djot",
        "creole", "creole",
        "dokuwiki", "dokuwiki",
        "gfm", "gfm",
        "haddock", "haddock",
        "commonmark", "commonmark"
    )

    try {
        outExt := extMap.Has(outFormat) ? extMap[outFormat] : outFormat
    } catch {
        return ""
    }

    return A_Temp "\Pandoc_" A_TickCount "_" index "_" nameNoExt "." outExt
}

_IsOutputFormatSupported(format) {
    format := StrLower(Trim(format))
    if (format == "")
        return false

    for f in AppState.PandocOutputFormats {
        if (StrLower(f) == format)
            return true
    }
    return false
}
