#Requires AutoHotkey v2.0

; File and folder operations with gitignore-style pattern matching.
class FileHelper {
    static MARKER_MID := Chr(1)
    static MARKER_END := Chr(2)

    static _simplePatterns := []
    static _regexPatterns := []
    static _regexReady := false

    ; ------------------------------------------------------------------------
    ; Build ignore regexes from AppState.IgnorePatterns.
    ; Splits patterns into simple (fast PathMatchSpecW) and complex (regex).
    ; ------------------------------------------------------------------------
    static BuildIgnoreRegexes() {
        this._simplePatterns := []
        this._regexPatterns := []
        this._regexReady := false

        if !IsObject(AppState.IgnorePatterns) || AppState.IgnorePatterns.Length == 0
            return

        for rawPattern in AppState.IgnorePatterns {
            pattern := Trim(rawPattern)
            if pattern == "" || SubStr(pattern, 1, 1) == "#" || SubStr(pattern, 1, 1) == "!"
                continue

            if InStr(pattern, "**") || InStr(pattern, "?") {
                regexStr := this._GitignoreToRegex(pattern)
                if regexStr != "" {
                    try {
                        RegExMatch("", regexStr)   ; validate regex
                        this._regexPatterns.Push({ pattern: pattern, regex: regexStr })
                    } catch {
                        ; Skip invalid patterns silently (could log here)
                    }
                }
            } else {
                this._simplePatterns.Push(pattern)
            }
        }

        this._regexReady := true
    }

    ; ------------------------------------------------------------------------
    ; Convert gitignore-style pattern to AHK RegEx string.
    ; ------------------------------------------------------------------------
    static _GitignoreToRegex(pattern) {
        ; Trim trailing slash
        patLen := StrLen(pattern)
        if patLen > 0 && SubStr(pattern, patLen, 1) == "/"
            pattern := SubStr(pattern, 1, patLen - 1)

        ; Remove leading ^ if present (not used in our context)
        if SubStr(pattern, 1, 1) == "^"
            pattern := SubStr(pattern, 2)

        ; Replace special sequences with markers
        pattern := StrReplace(pattern, "/**/", this.MARKER_MID)
        pattern := StrReplace(pattern, "/**", this.MARKER_END)

        ; Pre-allocate result buffer for performance
        result := ""
        VarSetStrCapacity(&result, StrLen(pattern) * 2 + 20)

        i := 1
        len := StrLen(pattern)
        while i <= len {
            ch := SubStr(pattern, i, 1)

            if ch == this.MARKER_MID {
                result .= "(?:[\\/].*)?"
                i++
            } else if ch == this.MARKER_END {
                result .= "(?:[\\/].*)?"
                i++
            } else if ch == "*" {
                this._HandleAsterisk(pattern, &i, len, &result)
            } else if ch == "?" {
                result .= "[^\\/]"
                i++
            } else if ch == "/" {
                result .= "[\\/]"
                i++
            } else {
                result .= this._EscapeRegexChar(ch)
                i++
            }
        }

        return "^" result "(?:[\\/].*)?$"
    }

    ; ------------------------------------------------------------------------
    ; Handle '*' and '**' patterns, advancing the index accordingly.
    ; ------------------------------------------------------------------------
    static _HandleAsterisk(pattern, &i, len, &result) {
        if i < len && SubStr(pattern, i + 1, 1) == "*" {
            ; Double asterisk
            prevCh := (i > 1) ? SubStr(pattern, i - 1, 1) : ""
            nextCh := (i + 2 <= len) ? SubStr(pattern, i + 2, 1) : ""

            if (prevCh == "" || prevCh == "/") && nextCh == "/" {
                ; **/ matches any number of directories
                result .= "(?:.*[\\/])?"
                i += 3
            } else if i + 1 == len {
                ; ** at end matches anything (including path separators)
                result .= ".*"
                i += 2
            } else {
                ; Unsupported ** usage - treat as single * (not path separator)
                result .= "[^\\/]*"
                i++
            }
        } else {
            ; Single * matches any non-separator characters
            result .= "[^\\/]*"
            i++
        }
    }

    ; ------------------------------------------------------------------------
    ; Escape a single character for regex if it is a special metacharacter.
    ; ------------------------------------------------------------------------
    static _EscapeRegexChar(ch) {
        if ch ~= "[\\.\\^\$\(\)\|\[\]\{\}\+\\\\]"
            return "\\" ch
        return ch
    }

    ; ------------------------------------------------------------------------
    ; Check if a file or folder path should be ignored.
    ; ------------------------------------------------------------------------
    static ShouldIgnore(filePath) {
        if !IsObject(AppState.IgnorePatterns) || AppState.IgnorePatterns.Length == 0
            return false

        if !this._regexReady
            this.BuildIgnoreRegexes()

        normalized := StrReplace(filePath, "\", "/")
        while SubStr(normalized, -1) == "/"
            normalized := SubStr(normalized, 1, StrLen(normalized) - 1)

        SplitPath(filePath, &fileName)

        ; Fast check using PathMatchSpecW for simple patterns
        for pattern in this._simplePatterns {
            try {
                if DllCall("shlwapi\PathMatchSpecW", "Str", normalized, "Str", pattern, "Int")
                    return true
                if DllCall("shlwapi\PathMatchSpecW", "Str", fileName, "Str", pattern, "Int")
                    return true
            } catch {
                ; Ignore DllCall errors
            }
        }

        ; Slow regex check for complex patterns
        for entry in this._regexPatterns {
            try {
                if RegExMatch(normalized, entry.regex)
                    return true
            } catch {
                ; Ignore regex errors
            }
        }

        return false
    }

    ; ------------------------------------------------------------------------
    ; Read multiple files and concatenate their content with headers.
    ; ------------------------------------------------------------------------
    static ReadMultipleFilesAsText(filePaths) {
        result := ""
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        for idx, filePath in filePaths {
            filePath := Trim(filePath)
            if filePath == "" || this.ShouldIgnore(filePath)
                continue
            result .= this.BuildFileHeader(filePath, timestamp)
            result .= this.ReadFileContentSafe(filePath)
        }
        return RTrim(result, "`n")
    }

    ; ------------------------------------------------------------------------
    ; Build a header comment for a file.
    ; ------------------------------------------------------------------------
    static BuildFileHeader(filePath, timestamp) {
        SplitPath(filePath, &fileName)
        fileSize := FileGetSize(filePath)
        sizeStr := this.FormatBytes(fileSize)
        return "; =========================================================================`n"
            . "; FILE: " filePath "`n"
            . "; NAME: " fileName " | SIZE: " sizeStr " | TIME: " timestamp "`n"
            . "; =========================================================================`n"
    }

    ; ------------------------------------------------------------------------
    ; Safely read a file's UTF-8 content; return error message on failure.
    ; ------------------------------------------------------------------------
    static ReadFileContentSafe(filePath) {
        try {
            content := FileRead(filePath, "UTF-8")
            return content "`n`n"
        } catch as err {
            return "[ERROR: Failed to read file - " err.Message "]`n`n"
        }
    }

    ; ------------------------------------------------------------------------
    ; Collect all files from a folder (optionally recursive).
    ; Uses native "FR" loop for speed.
    ; ------------------------------------------------------------------------
    static CollectFilesFromFolder(folderPath, recursive := true, fileList := unset) {
        if !IsSet(fileList)
            fileList := []

        folderPath := RTrim(folderPath, "\/")
        if this.ShouldIgnore(folderPath)
            return fileList

        try {
            if recursive {
                loop files, folderPath "\*", "FR" {
                    if !this.ShouldIgnore(A_LoopFileFullPath)
                        fileList.Push(A_LoopFileFullPath)
                }
            } else {
                loop files, folderPath "\*", "F" {
                    if !this.ShouldIgnore(A_LoopFileFullPath)
                        fileList.Push(A_LoopFileFullPath)
                }
            }
        }
        return fileList
    }

    ; ------------------------------------------------------------------------
    ; Read content from multiple folders (recursively) and concatenate.
    ; ------------------------------------------------------------------------
    static ReadMultipleFoldersAsText(folderPaths) {
        allFiles := []
        for folder in folderPaths {
            folder := Trim(folder)
            if PathDetector.IsFolderPath(folder) {
                files := this.CollectFilesFromFolder(folder, true)
                for f in files
                    allFiles.Push(f)
            }
        }
        if allFiles.Length == 0
            return ""
        return this.ReadMultipleFilesAsText(allFiles)
    }

    ; ------------------------------------------------------------------------
    ; Format file size in human-readable units.
    ; ------------------------------------------------------------------------
    static FormatBytes(bytes) {
        if bytes < 1024
            return bytes " B"
        else if bytes < 1048576
            return Round(bytes / 1024, 1) " KB"
        else if bytes < 1073741824
            return Round(bytes / 1048576, 1) " MB"
        else if bytes < 1099511627776
            return Round(bytes / 1073741824, 1) " GB"
        else
            return Round(bytes / 1099511627776, 1) " TB"
    }
}
