#Requires AutoHotkey v2.0

; -----------------------------------------------------------------------------
; Detect input format from file extension (returns format name or "").
; Uses lazy‑initialized static map with safe fallback.
; -----------------------------------------------------------------------------
_DetectInputFormat(filePath) {
    try {
        SplitPath(filePath, , , &ext)
    } catch {
        return ""
    }
    ext := StrLower(ext)
    if (ext == "")
        return ""

    for fmt in AppState.PandocInputFormats {
        if (fmt == ext)
            return fmt
    }

    static extMap := ""
    if (extMap == "" || !IsObject(extMap)) {
        try {
            extMap := Map(
                "adoc", "asciidoc", "bib", "bibtex", "md", "markdown",
                "markdown", "markdown", "mkd", "markdown", "mdown", "markdown",
                "html", "html", "htm", "html", "tex", "latex", "latex", "latex",
                "rst", "rst", "rtf", "rtf", "odt", "odt", "epub", "epub",
                "ipynb", "ipynb", "mediawiki", "mediawiki", "org", "org",
                "textile", "textile", "t2t", "t2t", "csv", "csv", "tsv", "tsv",
                "json", "json", "xml", "xml", "docx", "docx", "pptx", "pptx",
                "xlsx", "xlsx", "jats", "jats", "jira", "jira", "ris", "ris",
                "pod", "pod", "man", "man", "mdoc", "mdoc", "muse", "muse",
                "native", "native", "opml", "opml", "typst", "typst",
                "vimwiki", "vimwiki", "djot", "djot", "creole", "creole",
                "dokuwiki", "dokuwiki", "gfm", "gfm", "haddock", "haddock",
                "commonmark", "commonmark"
            )
        } catch {
            return ""
        }
    }

    try {
        if (extMap.Has(ext))
            return extMap[ext]
    } catch {
        ; fall through
    }
    return ""
}

; -----------------------------------------------------------------------------
; Build output file path in temp folder with appropriate extension.
; -----------------------------------------------------------------------------
_BuildOutputPath(inFile, outFormat) {
    SplitPath(inFile, &name, &dir, &ext, &nameNoExt)
    static extMap := Map(
        "docx", "docx", "html", "html", "markdown", "md", "latex", "tex",
        "pdf", "pdf", "rst", "rst", "rtf", "rtf", "odt", "odt", "epub", "epub",
        "ipynb", "ipynb", "mediawiki", "mediawiki", "org", "org",
        "textile", "textile", "t2t", "t2t", "csv", "csv", "tsv", "tsv",
        "json", "json", "xml", "xml", "pptx", "pptx", "xlsx", "xlsx",
        "jats", "jats", "jira", "jira", "ris", "ris", "pod", "pod",
        "man", "man", "mdoc", "mdoc", "muse", "muse", "native", "native",
        "opml", "opml", "typst", "typst", "vimwiki", "vimwiki",
        "djot", "djot", "creole", "creole", "dokuwiki", "dokuwiki",
        "gfm", "gfm", "haddock", "haddock", "commonmark", "commonmark"
    )
    outExt := extMap.Has(outFormat) ? extMap[outFormat] : outFormat
    return A_Temp "\Pandoc_" A_TickCount "_" nameNoExt "." outExt
}

; -----------------------------------------------------------------------------
; Check if output format is supported (defensive).
; -----------------------------------------------------------------------------
_IsOutputFormatSupported(format) {
    for f in AppState.PandocOutputFormats {
        if (f == format)
            return true
    }
    return false
}
