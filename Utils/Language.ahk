#Requires AutoHotkey v2.0

class LanguagePack {
    static CSVPath   := A_ScriptDir "\lang.csv"
    static CacheDir  := A_ScriptDir "\langs"
    static CacheExt  := ".lang"

    static _translations := Map()
    static _loadedCode  := ""
    static _available   := []
    static _defaultLang := "en"

    static Init() {
        if !DirExist(this.CacheDir)
            DirCreate(this.CacheDir)

        this._ScanCache()

        if this._available.Length == 0 && FileExist(this.CSVPath) {
            this.BuildAllFromCSV()
            this._ScanCache()
        }
    }

    static _ScanCache() {
        this._available := []
        Loop Files, this.CacheDir "\*" this.CacheExt, "F" {
            code := SubStr(A_LoopFileName, 1, StrLen(A_LoopFileName) - StrLen(this.CacheExt))
            this._available.Push(code)
        }
    }

    static BuildAllFromCSV(csvPath := "") {
        if (csvPath = "")
            csvPath := this.CSVPath

        if !FileExist(csvPath)
            return false

        try {
            raw := FileRead(csvPath, "UTF-8")
            if SubStr(raw, 1, 1) == Chr(0xFEFF)
                raw := SubStr(raw, 2)

            lines := StrSplit(raw, "`n", "`r")
            if lines.Length == 0
                return false

            headerFields := this._ParseCSVLine(lines[1])
            langCodes := []
            for h in headerFields {
                h := Trim(h)
                if h != "key" && h != ""
                    langCodes.Push(h)
            }
            if langCodes.Length == 0
                return false

            buffers := Map()
            for code in langCodes
                buffers[code] := ""

            Loop lines.Length - 1 {
                idx := A_Index + 1
                line := lines[idx]
                if Trim(line) == ""
                    continue

                fields := this._ParseCSVLine(line)
                if fields.Length < 2
                    continue

                key := Trim(fields[1])
                if key == ""
                    continue

                keyUpper := StrUpper(key)

                Loop langCodes.Length {
                    ci := A_Index
                    valIndex := ci + 1
                    val := (valIndex <= fields.Length) ? Trim(fields[valIndex]) : ""
                    val := StrReplace(val, "`r", "")
                    val := StrReplace(val, "`n", "\\n")
                    buffers[langCodes[ci]] .= keyUpper "=" val "`n"
                }
            }

            if !DirExist(this.CacheDir)
                DirCreate(this.CacheDir)

            for code in langCodes {
                fpath := this.CacheDir "\" code this.CacheExt
                try FileDelete(fpath)
                FileAppend(buffers[code], fpath, "UTF-8")
            }

            return true
        } catch {
            return false
        }
    }

    ; Load language file using Loop Read for line-by-line processing.
    ; This avoids loading the entire file into memory and splitting into
    ; a large array, which reduces peak memory usage and allocation overhead.
    static Load(code) {
        if code == this._loadedCode
            return true

        fpath := this.CacheDir "\" code this.CacheExt

        if !FileExist(fpath) {
            if code != this._defaultLang {
                fpath := this.CacheDir "\" this._defaultLang this.CacheExt
                if !FileExist(fpath)
                    return false
                code := this._defaultLang
            } else {
                return false
            }
        }

        try {
            newMap := Map()

            ; Use Loop Read for memory-efficient line-by-line processing
            Loop Read, fpath {
                line := Trim(A_LoopReadLine)
                if line == "" || SubStr(line, 1, 1) == "#"
                    continue

                eqPos := InStr(line, "=")
                if eqPos == 0
                    continue

                key := Trim(SubStr(line, 1, eqPos - 1))
                val := SubStr(line, eqPos + 1)
                val := StrReplace(val, "\n", "`n")

                if key != ""
                    newMap[StrUpper(key)] := val
            }

            this._translations := newMap
            this._loadedCode  := code
            return true
        } catch {
            return false
        }
    }

    static Get(key, default := "") {
        keyUpper := StrUpper(key)
        if this._translations.Has(keyUpper) {
            val := this._translations[keyUpper]
            if val != ""
                return val
        }
        return (default != "") ? default : key
    }

    static GetLoaded()    => this._loadedCode
    static GetAvailable() => this._available
    static IsAvailable(code) {
        for c in this._available {
            if c == code
                return true
        }
        return false
    }

    ; Parse a single CSV line handling quoted fields and escaped quotes.
    ; Optimized to minimize string concatenation within the loop.
    static _ParseCSVLine(line) {
        fields := []
        field := ""
        inQuotes := false
        i := 1
        len := StrLen(line)

        while i <= len {
            ch := SubStr(line, i, 1)

            if ch == '"' {
                if inQuotes && i + 1 <= len && SubStr(line, i + 1, 1) == '"' {
                    field .= '"'
                    i += 2
                    continue
                }
                inQuotes := !inQuotes
                i++
                continue
            }

            if ch == "," && !inQuotes {
                fields.Push(field)
                field := ""
                i++
                continue
            }

            field .= ch
            i++
        }
        fields.Push(field)
        return fields
    }
}

class Language {
    static current := "zh"

    static Load() {
        LanguagePack.Init()

        saved := this._ReadSavedLang()
        target := (saved != "") ? saved : this.current

        if !LanguagePack.IsAvailable(target)
            target := "en"

        LanguagePack.Load(target)
        this.current := target
    }

    static SetLanguage(code) {
        if code == this.current
            return true

        if !LanguagePack.IsAvailable(code) && FileExist(LanguagePack.CSVPath) {
            LanguagePack.BuildAllFromCSV()
            LanguagePack.Init()
        }

        if LanguagePack.Load(code) {
            actual := LanguagePack.GetLoaded()
            this.current := actual
            this._WriteSavedLang(actual)
            return true
        }
        return false
    }

    static Get(key, default := "", params*) {
        text := LanguagePack.Get(key, default)

        if params.Length > 0 {
            for i, p in params {
                text := StrReplace(text, "{" i "}", p)
            }
        }
        return text
    }

    static GetCurrent()  => this.current
    static GetLanguages() => LanguagePack.GetAvailable()

    static _ReadSavedLang() {
        try {
            cfg := AppState.ConfigFile
            if FileExist(cfg) {
                val := IniRead(cfg, "General", "language", "")
                if val != ""
                    return val
            }
        } catch {
        }
        return ""
    }

    static _WriteSavedLang(code) {
        try {
            cfg := AppState.ConfigFile
            cfgDir := SubStr(cfg, 1, InStr(cfg, "\", , -1))
            if !DirExist(cfgDir)
                DirCreate(cfgDir)
            IniWrite(code, cfg, "General", "language")
        } catch {
        }
    }
}

Lang(key, default := "", params*) {
    if params.Length == 0
        return Language.Get(key, default)
    else
        return Language.Get(key, default, params*)
}
