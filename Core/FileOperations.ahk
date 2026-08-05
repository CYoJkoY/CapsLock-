#Requires AutoHotkey v2.0

class FileHelper {
    static MARKER_MID := Chr(1)
    static MARKER_END := Chr(2)

    static _simplePatterns := []
    static _regexPatterns := []
    static _regexReady := false

    static PATH_MATCH_SPEC := DllCall( "GetModuleHandle", "Str", "shlwapi", "Ptr" ) || DllCall( "LoadLibrary", "Str", "shlwapi", "Ptr" )

    static BuildIgnoreRegexes() {
        this._simplePatterns := []
        this._regexPatterns := []
        this._regexReady := false

        if !IsObject(AppState.IgnorePatterns) || AppState.IgnorePatterns.Length == 0
            return

        for rawPattern in AppState.IgnorePatterns {
            pattern := Trim(rawPattern)
            if pattern == ""
                continue
            if SubStr(pattern, 1, 1) == "#"
                continue
            if SubStr(pattern, 1, 1) == "!"
                continue

            ; Separate simple patterns (fast PathMatchSpecW) from complex patterns (slow regex)
            ; Patterns with ** or ? require regex; everything else uses native API
            if InStr(pattern, "**") || InStr(pattern, "?") {
                regexStr := this._GitignoreToRegex(pattern)
                if regexStr != "" {
                    try {
                        RegExMatch("", regexStr)
                        this._regexPatterns.Push({ pattern: pattern, regex: regexStr })
                    } catch {
                    }
                }
            } else {
                this._simplePatterns.Push(pattern)
            }
        }

        this._regexReady := true
    }

    ; Convert gitignore-style patterns to AHK RegEx strings
    ;
    ; Conversion rules:
    ;   /**/  ->  (?:[\/].*)?        (0+ intermediate directories)
    ;   /**   ->  (?:[\/].*)?        (optional trailing subpath)
    ;   **/   ->  (?:.*[\/])?        (optional leading directories)
    ;   *     ->  [^\/]*             (no path separators)
    ;   ?     ->  [^\/]              (single non-separator)
    ;   /     ->  [\/]               (path separator)
    static _GitignoreToRegex(pattern) {
        patLen := StrLen(pattern)
        if patLen > 0 && SubStr(pattern, patLen, 1) == "/"
            pattern := SubStr(pattern, 1, patLen - 1)

        if SubStr(pattern, 1, 1) == "^"
            pattern := SubStr(pattern, 2)

        pattern := StrReplace(pattern, "/**/", this.MARKER_MID)
        pattern := StrReplace(pattern, "/**", this.MARKER_END)

        result := ""
        i := 1
        len := StrLen(pattern)

        while i <= len {
            ch := SubStr(pattern, i, 1)

            if ch == this.MARKER_MID {
                result .= "(?:[\\/].*)?"
                i++
                continue
            }

            if ch == this.MARKER_END {
                result .= "(?:[\\/].*)?"
                i++
                continue
            }

            if ch == "*" {
                if i < len && SubStr(pattern, i + 1, 1) == "*" {
                    prevCh := (i > 1) ? SubStr(pattern, i - 1, 1) : ""
                    nextCh := (i + 2 <= len) ? SubStr(pattern, i + 2, 1) : ""

                    if (prevCh == "" || prevCh == "/") && nextCh == "/" {
                        result .= "(?:.*[\\/])?"
                        i += 3
                        continue
                    } else if i + 1 == len {
                        result .= ".*"
                        i += 2
                        continue
                    } else {
                        result .= "[^\\/]*"
                        i++
                        continue
                    }
                } else {
                    result .= "[^\\/]*"
                    i++
                    continue
                }
            }

            if ch == "?" {
                result .= "[^\\/]"
                i++
                continue
            }

            if ch == "/" {
                result .= "[\\/]"
                i++
                continue
            }

            if ch ~= "[\\.\\^\$\(\)\|\[\]\{\}\+\\\\]"
                result .= "\\" ch
            else
                result .= ch

            i++
        }

        return "^" result "(?:[\\/].*)?$"
    }

    static ShouldIgnore(filePath) {
        if !IsObject(AppState.IgnorePatterns) || AppState.IgnorePatterns.Length == 0
            return false

        if !this._regexReady
            this.BuildIgnoreRegexes()

        normalized := StrReplace(filePath, "\", "/")
        while SubStr(normalized, -1) == "/"
            normalized := SubStr(normalized, 1, StrLen(normalized) - 1)

        SplitPath(filePath, &fileName)

        ; Check simple patterns first using fast PathMatchSpecW API
        for pattern in this._simplePatterns {
            try {
                if DllCall("shlwapi\PathMatchSpecW", "str", normalized, "str", pattern, "int")
                    return true
                if DllCall("shlwapi\PathMatchSpecW", "str", fileName, "str", pattern, "int")
                    return true
            } catch {
            }
        }

        ; Check complex patterns with regex (only when necessary)
        for entry in this._regexPatterns {
            try {
                if RegExMatch(normalized, entry.regex)
                    return true
            } catch {
            }
        }

        return false
    }

    static PathMatchSpec( filePath, pattern ) {
        return DllCall( "shlwapi\PathMatchSpecW", "Str", filePath, "Str", pattern, "Int" )
    }

    static ReadMultipleFilesAsText(filePaths) {
        result := ""
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        for idx, filePath in filePaths {
            filePath := Trim(filePath)
            if filePath == ""
                continue
            if this.ShouldIgnore(filePath)
                continue
            result .= this.BuildFileHeader(filePath, timestamp)
            result .= this.ReadFileContentSafe(filePath)
        }
        return RTrim(result, "`n")
    }

    static BuildFileHeader(filePath, timestamp) {
        SplitPath(filePath, &fileName)
        fileSize := FileGetSize(filePath)
        sizeStr := this.FormatBytes(fileSize)
        header := "; =========================================================================`n"
        header .= "; FILE: " filePath "`n"
        header .= "; NAME: " fileName " | SIZE: " sizeStr " | TIME: " timestamp "`n"
        header .= "; =========================================================================`n"
        return header
    }

    static ReadFileContentSafe(filePath) {
        try {
            content := FileRead(filePath, "UTF-8")
            return content "`n`n"
        } catch as err {
            return "[ERROR: Failed to read file - " err.Message "]`n`n"
        }
    }

    ; Collect all files from a folder, optionally recursive.
    ; Uses built-in recursive Loop Files (flag "FR") for significant speedup
    ; over manual recursion, especially for deep directory trees.
    static CollectFilesFromFolder(folderPath, recursive := true, fileList := unset) {
        if !IsSet(fileList)
            fileList := []

        folderPath := RTrim(folderPath, "\/")

        if this.ShouldIgnore(folderPath)
            return fileList

        try {
            if recursive {
                ; Use native recursive file enumeration ("FR" = Files + Recurse)
                ; This is significantly faster than manual recursive function calls
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
