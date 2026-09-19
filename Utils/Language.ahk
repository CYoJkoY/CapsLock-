#Requires AutoHotkey v2.0

class LanguagePack {
    static CSVPath   := A_ScriptDir "\lang.csv"
    static CacheDir  := A_ScriptDir "\langs"
    static CacheExt  := ".lang"
    static CacheStampVersion := "1"
    static CacheStampFile := A_ScriptDir "\langs\_source.lang"

    static _translations := Map()
    static _loadedCode  := ""
    static _available   := []
    static _defaultLang := "en"

    static Init() {
        if !DirExist(this.CacheDir)
            DirCreate(this.CacheDir)

        this._ScanCache()

        if !FileExist(this.CSVPath)
            return

        ; The CSV is the source of truth. Rebuild generated language caches when
        ; the source has changed or a language cache is missing.
        if !this._IsCacheCurrent()
            this.BuildAllFromCSV()

        this._ScanCache()
    }

    static _IsCacheCurrent() {
        if this._available.Length == 0 || !FileExist(this.CacheStampFile)
            return false

        try {
            stamp := FileRead(this.CacheStampFile, "UTF-8")
            if SubStr(stamp, 1, 1) == Chr(0xFEFF)
                stamp := SubStr(stamp, 2)

            lines := StrSplit(stamp, "`n", "`r")
            if lines.Length < 3
                return false

            if Trim(lines[1]) != this.CacheStampVersion
                return false

            fingerprint := this._GetCSVFingerprint()
            if fingerprint == "" || Trim(lines[2]) != fingerprint
                return false

            expectedCodes := StrSplit(Trim(lines[3]), "|")
            if expectedCodes.Length == 0
                return false

            for code in expectedCodes {
                code := Trim(code)
                if code == "" || !FileExist(this.CacheDir "\" code this.CacheExt)
                    return false
            }

            return true
        } catch {
            return false
        }
    }

    static _GetCSVFingerprint() {
        try {
            raw := FileRead(this.CSVPath, "UTF-8")
            if SubStr(raw, 1, 1) == Chr(0xFEFF)
                raw := SubStr(raw, 2)
            return this._Fingerprint(raw)
        } catch {
            return ""
        }
    }

    static _Fingerprint(text) {
        ; Stable lightweight source fingerprint for cache invalidation.
        ; This is not intended as a cryptographic hash.
        hash := 2166136261
        Loop Parse, text {
            hash := Mod((hash ^ Ord(A_LoopField)) * 16777619, 4294967296)
        }
        return Format("{:08X}", hash)
    }

    static _ScanCache() {
        this._available := []
        Loop Files, this.CacheDir "\*" this.CacheExt, "F" {
            if A_LoopFileName == "_source.lang"
                continue

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

            records := this._ParseCSVRecords(raw)
            if !IsObject(records) || records.Length == 0
                return false

            headerFields := this._ParseCSVLine(records[1])
            langCodes := []
            for h in headerFields {
                h := Trim(h)
                if h != "key" && h != ""
                    langCodes.Push(h)
            }
            if langCodes.Length == 0
                return false

            ; Index of the fallback column (English). Values missing in a
            ; translation fall back to it, so a partially translated key
            ; never ends up showing the raw key name to the user.
            defaultIndex := 0
            Loop langCodes.Length {
                if langCodes[A_Index] == this._defaultLang {
                    defaultIndex := A_Index
                    break
                }
            }

            buffers := Map()
            for code in langCodes
                buffers[code] := ""

            Loop records.Length - 1 {
                idx := A_Index + 1
                line := records[idx]
                if Trim(line) == ""
                    continue

                fields := this._ParseCSVLine(line)
                if fields.Length != headerFields.Length
                    return false

                key := Trim(fields[1])
                if key == ""
                    continue

                keyUpper := StrUpper(key)

                fallback := ""
                if defaultIndex && (defaultIndex + 1) <= fields.Length {
                    fallback := Trim(fields[defaultIndex + 1])
                    fallback := StrReplace(fallback, "`r", "")
                    fallback := StrReplace(fallback, "`n", "\n")
                }

                Loop langCodes.Length {
                    ci := A_Index
                    valIndex := ci + 1
                    val := (valIndex <= fields.Length) ? Trim(fields[valIndex]) : ""
                    val := StrReplace(val, "`r", "")
                    val := StrReplace(val, "`n", "\n")
                    if val == "" && fallback != ""
                        val := fallback
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

            ; Record exactly which CSV source produced these cache files.
            ; The stamp is deliberately separate from *.lang so language
            ; discovery cannot mistake it for a locale code.
            if (csvPath == this.CSVPath) {
                stamp := this.CacheStampVersion "`n"
                    . this._Fingerprint(raw) "`n"
                    . Join(langCodes, "|")
                try FileDelete(this.CacheStampFile)
                try FileAppend(stamp, this.CacheStampFile, "UTF-8")
            }

            ; Any already-loaded locale now points at regenerated files.
            ; Force the next Load() to read the fresh cache instead of
            ; returning early on the previous locale code.
            this._translations := Map()
            this._loadedCode := ""

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
    static _ParseCSVRecords(raw) {
        records := []
        record := ""
        inQuotes := false
        i := 1
        len := StrLen(raw)

        while i <= len {
            ch := SubStr(raw, i, 1)

            if ch == '"' {
                record .= ch

                if inQuotes && i + 1 <= len && SubStr(raw, i + 1, 1) == '"' {
                    record .= '"'
                    i += 2
                    continue
                }

                inQuotes := !inQuotes
                i++
                continue
            }

            if (ch == "`r" || ch == "`n") {
                if inQuotes {
                    record .= "`n"

                    if ch == "`r" && i + 1 <= len && SubStr(raw, i + 1, 1) == "`n"
                        i += 2
                    else
                        i++

                    continue
                }

                records.Push(record)
                record := ""

                if ch == "`r" && i + 1 <= len && SubStr(raw, i + 1, 1) == "`n"
                    i += 2
                else
                    i++

                continue
            }

            record .= ch
            i++
        }

        if inQuotes
            return false

        if record != ""
            records.Push(record)

        return records
    }

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
