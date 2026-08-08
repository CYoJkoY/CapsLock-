#Requires AutoHotkey v2.0

class SecureIni {
    static _MAGIC  := 0x31585C43
    static _path   := ""
    static _data   := ""
    static _legacy := false

    static Open(path) {
        if this._path == path && this._data
            return
        this._path := path
        this._data := Map()
        this._data.CaseSense := false
        this._legacy := false
        if !FileExist(path)
            return
        f := FileOpen(path, "r")
        if !IsObject(f)
            return
        buf := Buffer(f.Length)
        f.RawRead(buf, f.Length)
        f.Close()
        if buf.Size >= 4 && NumGet(buf.Ptr, "UInt") == this._MAGIC {
            Encryption.CryptStream(buf, 4)
            this._Parse(StrGet(buf.Ptr + 4, "UTF-8"))
        } else {
            this._legacy := true
            this._Parse(this._StripBom(StrGet(buf.Ptr, "UTF-8")))
        }
    }

    static Get(section, key, default := "") {
        this._Ensure()
        if !this._data.Has(section)
            return default
        m := this._data[section]
        return m.Has(key) ? m[key] : default
    }

    static Set(section, key, value) {
        this._Ensure()
        this._Section(section)[key] := String(value)
    }

    static Save() {
        this._Ensure()
        text := this._Serialize()
        buf := Buffer(4 + StrPut(text, "UTF-8"))
        NumPut("UInt", this._MAGIC, buf)
        StrPut(text, buf.Ptr + 4, buf.Size - 4, "UTF-8")
        Encryption.CryptStream(buf, 4)
        f := FileOpen(this._path, "w")
        if !IsObject(f)
            return
        f.RawWrite(buf, buf.Size)
        f.Close()
        this._legacy := false
    }

    static WasLegacy() => this._legacy

    static _Ensure() {
        if !this._data
            this.Open(AppState.ConfigFile)
    }

    static _Section(name) {
        if !this._data.Has(name) {
            m := Map()
            m.CaseSense := false
            this._data[name] := m
        }
        return this._data[name]
    }

    static _Parse(text) {
        section := ""
        for line in StrSplit(text, "`n", "`r") {
            line := Trim(line)
            if line == "" || SubStr(line, 1, 1) == ";"
                continue
            if SubStr(line, 1, 1) == "[" && SubStr(line, -1) == "]" {
                section := SubStr(line, 2, -1)
                continue
            }
            pos := InStr(line, "=")
            if pos > 1 && section != ""
                this._Section(section)[SubStr(line, 1, pos - 1)] := SubStr(line, pos + 1)
        }
    }

    static _Serialize() {
        sb := ""
        for section, pairs in this._data {
            sb .= "[" section "]`n"
            for key, value in pairs
                sb .= key "=" value "`n"
        }
        return sb
    }

    static _StripBom(text) {
        return SubStr(text, 1, 1) == Chr(0xFEFF) ? SubStr(text, 2) : text
    }
}
