#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Convert files using Pandoc and paste the result
; ---------------------------------------------------------------------------
ConvertWithPandoc() {
    ; --- FIX: Capture current active window as paste target ---
    ; Previously missing - caused pasting to wrong (cached) window.
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
        if InStr(FileExist(path), "D") {          ; folder
            collected := FileHelper.CollectFilesFromFolder(path, true)
            for f in collected
                finalFiles.Push(f)
        } else {                                  ; file
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
    pandoc := AppState.PandocExe
    if (pandoc == "" || !FileExist(pandoc)) {
        ShowToolTip(Lang("MSG_PANDOC_NOT_FOUND", "Pandoc executable not found. Please set path in settings."), 3000)
        return
    }

    ; 6. Validate output format
    outFormat := AppState.PandocOutputFormat
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
    failedCount := 0

    for idx, inFile in filteredFiles {
        ; Update progress
        if showProgress {
            SplitPath(inFile, &fileName)
            progressText.Text := Lang("MSG_PANDOC_PROGRESS", "Converting {1}/{2}: {3}", idx, total, fileName)
            progressBar.Value := (idx / total) * 100
        }

        ; Detect input format (safely - returns "" on any error to skip file gracefully)
        inFormat := _DetectInputFormat(inFile)
        if (inFormat == "") {
            skippedFiles.Push(inFile)
            continue
        }

        ; Build output file path
        outFile := _BuildOutputPath(inFile, outFormat)
        if (outFile == "") {
            failedCount++
            continue
        }

        ; Run pandoc
        cmd := '"' pandoc '" -f ' inFormat ' -t ' outFormat ' -o "' outFile '" "' inFile '"'
        try {
            RunWait(cmd, , "Hide")
            if (FileExist(outFile)) {
                outputFiles.Push(outFile)
            } else {
                failedCount++
            }
        } catch as err {
            failedCount++
        }
    }

    ; 9. Destroy progress GUI
    if showProgress {
        try progressGui.Destroy()
    }

    ; 10. Report skipped files
    if (skippedFiles.Length > 0) {
        skippedMsg := Lang("MSG_PANDOC_SKIPPED_FILES", "Skipped unsupported files:`n{1}", Join(skippedFiles, "`n"))
        ShowToolTip(skippedMsg, 3000)
    }

    ; 11. Paste results if any
    if (outputFiles.Length == 0) {
        ShowToolTip(Lang("MSG_PANDOC_NO_OUTPUT", "No files were converted successfully"), 2000)
        return
    }

    ClipboardHelper.SetClipboardFiles(outputFiles)
    ActivateAndPaste()

    for f in outputFiles {
        CleanupManager.ScheduleDeletion(f)
    }

    ShowToolTip(Lang("MSG_PANDOC_SUCCESS", "Converted {1} file(s)", outputFiles.Length), 2000)
}

; ---------------------------------------------------------------------------
; Detect input format from file extension (returns format name or "")
; FIXED: Lazy-init pattern with try-catch prevents crash when static map
;        initialization fails (AHK v2 bug: static vars can enter unassigned
;        state after a failed init, causing script-terminating error).
; ---------------------------------------------------------------------------
_DetectInputFormat(filePath) {
    ; Safely extract extension - return "" on any failure
    try {
        SplitPath(filePath, , , &ext)
    } catch {
        return ""
    }
    ext := StrLower(ext)
    if (ext == "") 
        return ""

    ; 1. Check if extension matches a known input format directly
    for fmt in AppState.PandocInputFormats {
        if (fmt == ext) {
            return fmt
        }
    }

    ; 2. Common extension → format name mapping
    ;    Uses lazy-init with defensive check: if the static map failed to
    ;    initialize on a previous call (leaving it unassigned), we detect
    ;    that and retry initialization. This prevents the fatal error:
    ;    "This static variable has not been assigned a value."
    static extMap := ""

    ; Check if extMap needs (re)initialization
    if (extMap == "" || !IsObject(extMap)) {
        try {
            extMap := Map(
                "adoc", "asciidoc",
                "bib",  "bibtex",
                "md",   "markdown",
                "markdown", "markdown",
                "mkd",  "markdown",
                "mdown", "markdown",
                "html", "html",
                "htm",  "html",
                "tex",  "latex",
                "latex", "latex",
                "rst",  "rst",
                "rtf",  "rtf",
                "odt",  "odt",
                "epub", "epub",
                "ipynb", "ipynb",
                "mediawiki", "mediawiki",
                "org",  "org",
                "textile", "textile",
                "t2t",  "t2t",
                "csv",  "csv",
                "tsv",  "tsv",
                "json", "json",
                "xml",  "xml",
                "docx", "docx",
                "pptx", "pptx",
                "xlsx", "xlsx",
                "jats", "jats",
                "jira", "jira",
                "ris",  "ris",
                "pod",  "pod",
                "man",  "man",
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
        } catch {
            ; If Map construction fails for any reason, return empty
            ; to skip this file gracefully instead of crashing.
            return ""
        }
    }

    ; Safe access: only call .Has() if extMap is a valid object
    try {
        if (extMap.Has(ext)) {
            return extMap[ext]
        }
    } catch {
        ; Fall through to unsupported
    }

    return ""  ; unsupported
}

; ---------------------------------------------------------------------------
; Build output file path: temp dir + basename + appropriate extension
; ---------------------------------------------------------------------------
_BuildOutputPath(inFile, outFormat) {
    SplitPath(inFile, &name, &dir, &ext, &nameNoExt)
    ; Determine extension for output format
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
    outExt := extMap.Has(outFormat) ? extMap[outFormat] : outFormat
    return A_Temp "\Pandoc_" A_TickCount "_" nameNoExt "." outExt
}

; ---------------------------------------------------------------------------
; Validate output format against supported list
; ---------------------------------------------------------------------------
_IsOutputFormatSupported(format) {
    for f in AppState.PandocOutputFormats {
        if (f == format) 
            return true
    }
    return false
}
