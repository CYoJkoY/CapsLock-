#Requires AutoHotkey v2.0

class GistSync {
    static API_BASE := "https://api.github.com"
    static ValidExts := ["ini", "prompt"]
    static B64_MARKER := "base64:"

    static Upload(localDir, token, gistId := "") {
        token := Trim(token)
        gistId := Trim(gistId)
        if !DirExist(localDir)
            throw Error(Lang("MSG_GIST_DIR_NOT_FOUND"))

        if token == ""
            throw Error(Lang("MSG_GIST_NO_TOKEN"))

        fileParts := this._BuildFileParts(this._CollectFiles(localDir))
        if fileParts.Length == 0
            throw Error(Lang("MSG_GIST_NO_FILES_TO_UPLOAD"))

        json := '{"files":{' . Join(fileParts, ",") . '}}'
        url := this.API_BASE "/gists" . (gistId != "" ? "/" . gistId : "")
        response := this._SendRequest(gistId != "" ? "PATCH" : "POST", url, token, json)
        if gistId != ""
            return gistId

        if RegExMatch(response, '"id"\s*:\s*"([^"]+)"', &m)
            return m[1]

        throw Error(Lang("MSG_GIST_NO_ID_IN_RESPONSE"))
    }

    static Download(gistId, token, localDir, mode) {
        if token == ""
            throw Error(Lang("MSG_GIST_NO_TOKEN"))

        if gistId == ""
            throw Error(Lang("MSG_GIST_NO_GISTID"))

        response := this._SendRequest("GET", this.API_BASE "/gists/" . gistId, token)
        files := this._ParseFiles(response)
        if files.Count == 0
            throw Error(Lang("MSG_GIST_EMPTY_GIST"))

        if !DirExist(localDir)
            DirCreate(localDir)

        written := 0
        for relPath, content in files {
            if mode == "append" && FileExist(localDir "\" relPath)
                continue
            this._WriteFile(localDir "\" relPath, content)
            written++
        }
        return written
    }

    static _BuildFileParts(files) {
        parts := []
        for relPath, content in files {
            if content == ""
                continue

            parts.Push(ApiJsonHelper.Escape(this._EncodeName(relPath))
                . ':{"content":' . ApiJsonHelper.Escape(content) . '}')
        }
        return parts
    }

    static _CollectFiles(dir) {
        dir := RTrim(dir, "\/")
        files := Map()
        Loop Files, dir "\*", "FR" {
            if InStr(FileExist(A_LoopFileFullPath), "D")
                continue

            SplitPath(A_LoopFileFullPath, , , &ext)
            if !this._IsValidExt(ext)
                continue

            relPath := StrReplace(SubStr(A_LoopFileFullPath, StrLen(dir) + 2), "\", "/")
            content := this._ReadFileSmart(A_LoopFileFullPath)
            if content != ""
                files[relPath] := content
        }
        return files
    }

    static _ReadFileSmart(path) {
        f := FileOpen(path, "r")
        if !IsObject(f)
            return ""

        buf := Buffer(f.Length)
        f.RawRead(buf, f.Length)
        f.Close()
        if buf.Size == 0
            return ""

        if !this._IsUtf8(buf)
            return this.B64_MARKER . this._Base64Encode(buf)

        text := StrGet(buf.Ptr, buf.Size, "UTF-8")
        return SubStr(text, 1, 1) == Chr(0xFEFF) ? SubStr(text, 2) : text
    }

    static _WriteFile(fullPath, content) {
        SplitPath(fullPath, , &dir)
        if !DirExist(dir)
            DirCreate(dir)

        if SubStr(content, 1, StrLen(this.B64_MARKER)) != this.B64_MARKER {
            FileAppend(content, fullPath, "UTF-8")
            return
        }

        buf := this._Base64Decode(SubStr(content, StrLen(this.B64_MARKER) + 1))
        f := FileOpen(fullPath, "w")
        if !IsObject(f)
            return

        f.RawWrite(buf, buf.Size)
        f.Close()
    }

    static _IsValidExt(ext) {
        for allowed in this.ValidExts
            if ext == allowed
                return true

        return false
    }

    static _IsUtf8(buf) {
        return DllCall("MultiByteToWideChar", "UInt", 65001, "UInt", 0x8,
            "Ptr", buf.Ptr, "Int", buf.Size, "Ptr", 0, "Int", 0) > 0
    }

    static _Base64Encode(buf) {
        len := 0
        DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size,
            "UInt", 0x40000001, "Ptr", 0, "UInt*", &len)

        out := Buffer((len + 1) * 2, 0)
        DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size,
            "UInt", 0x40000001, "Ptr", out.Ptr, "UInt*", &len)

        return StrGet(out.Ptr, "UTF-16")
    }

    static _Base64Decode(str) {
        len := 0
        DllCall("crypt32\CryptStringToBinaryW", "Str", str, "UInt", 0,
            "UInt", 0x1, "Ptr", 0, "UInt*", &len, "Ptr", 0, "Ptr", 0)

        buf := Buffer(len)
        DllCall("crypt32\CryptStringToBinaryW", "Str", str, "UInt", 0,
            "UInt", 0x1, "Ptr", buf.Ptr, "UInt*", &len, "Ptr", 0, "Ptr", 0)

        return buf
    }

    static _SendRequest(method, url, token, body := "") {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open(method, url, true)
        whr.SetRequestHeader("Authorization", "token " . token)
        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.SetTimeouts(30000, 30000, 30000, 30000)

        if body == ""
            whr.Send()
        else
            whr.Send(this._ToUtf8Array(body))

        whr.WaitForResponse()
        status := whr.Status
        if status < 200 || status >= 300
            throw Error(Lang("MSG_GIST_HTTP_ERROR", , status, this._Truncate(whr.ResponseText)))

        return whr.ResponseText
    }

    static _ToUtf8Array(str) {
        size := StrPut(str, "UTF-8") - 1
        buf := Buffer(size + 1)
        StrPut(str, buf.Ptr, size + 1, "UTF-8")
        arr := ComObjArray(0x11, size)

        loop size
            arr[A_Index - 1] := NumGet(buf.Ptr + A_Index - 1, "UChar")
        return arr
    }

    static _EncodeName(relPath) {
        name := StrReplace(relPath, "%", "%25")
        name := StrReplace(name, "/", "%2F")
        return StrReplace(name, "\", "%2F")
    }

    static _DecodeName(name) {
        rel := StrReplace(name, "%2F", "\")
        rel := StrReplace(rel, "%25", "%")
        if rel == "" || InStr(rel, "..") || InStr(rel, ":")
            return ""

        return rel
    }

    static _ParseFiles(json) {
        result := Map()
        pos := 1
        while RegExMatch(json, '"([^"]+)"\s*:\s*\{[^{}]*"content"\s*:\s*"((?:[^"\\]|\\.)*)"', &m, pos) {
            pos := m.Pos + m.Len
            relPath := this._DecodeName(m[1])
            if relPath == ""
                continue

            result[relPath] := ApiJsonHelper.Unescape(m[2])
        }
        return result
    }

    static _Truncate(text, maxLen := 500) {
        return StrLen(text) <= maxLen ? text : SubStr(text, 1, maxLen) . "…"
    }
}
