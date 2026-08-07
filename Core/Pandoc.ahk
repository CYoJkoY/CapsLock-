#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Convert files using Pandoc and paste the result
; ---------------------------------------------------------------------------
ConvertWithPandoc() {
    ; 1. Get file paths from clipboard (as text lines)
    text := A_Clipboard
    if (text == "") {
        ShowToolTip(Lang("MSG_CLIPBOARD_EMPTY", "Clipboard is empty"), 2000)
        return
    }

    ; 2. Parse file paths (only existing files, not folders)
    filePaths := PathDetector.GetValidPathsFromText(text, "file")
    if (filePaths.Length == 0) {
        ShowToolTip(Lang("MSG_NO_FILES_FOUND", "No valid files found in clipboard"), 2000)
        return
    }

    ; 3. Validate Pandoc executable
    pandoc := AppState.PandocExe
    if (pandoc == "" || !FileExist(pandoc)) {
        ShowToolTip(Lang("MSG_PANDOC_NOT_FOUND", "Pandoc executable not found. Please set path in settings."), 3000)
        return
    }

    ; 4. Get output format
    outFormat := AppState.PandocOutputFormat
    if (!_IsOutputFormatSupported(outFormat)) {
        ShowToolTip(Lang("MSG_PANDOC_INVALID_OUTPUT", "Invalid output format: {1}", outFormat), 2500)
        return
    }

    ; 5. Convert each file
    outputFiles := []
    failedCount := 0
    for idx, inFile in filePaths {
        inFormat := _DetectInputFormat(inFile)
        if (inFormat == "") {
            ShowToolTip(Lang("MSG_PANDOC_UNSUPPORTED_INPUT", "Unsupported input format: {1}", inFile), 2000)
            failedCount++
            continue
        }

        ; Generate output file path in temp folder
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
            ShowToolTip(Lang("MSG_PANDOC_FAILED", "Conversion failed: {1}", err.Message), 2500)
            failedCount++
        }
    }

    ; 6. Paste results
    if (outputFiles.Length == 0) {
        ShowToolTip(Lang("MSG_PANDOC_NO_OUTPUT", "No files were converted successfully"), 2000)
        return
    }

    ; Copy files to clipboard and paste
    ClipboardHelper.SetClipboardFiles(outputFiles)
    ActivateAndPaste()

    ; Schedule cleanup of temporary files
    for f in outputFiles {
        CleanupManager.ScheduleDeletion(f)
    }

    ShowToolTip(Lang("MSG_PANDOC_SUCCESS", "Converted {1} file(s)", outputFiles.Length), 2000)
}

; ---------------------------------------------------------------------------
; Detect input format from file extension (returns format name or "")
; ---------------------------------------------------------------------------
_DetectInputFormat(filePath) {
    SplitPath(filePath, , , &ext)
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
    static map := Map(
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
    if (map.Has(ext)) {
        return map[ext]
    }

    ; 3. If extension itself is a valid Pandoc input format (e.g., "docx" already caught earlier)
    ; but we already did that in step 1.

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
