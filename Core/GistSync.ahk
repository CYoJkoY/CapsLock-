#Requires AutoHotkey v2.0

class GistSync {
    static API_BASE := "https://api.github.com"
    static _http := ComObject("WinHttp.WinHttpRequest.5.1")
    static ValidExts := ["ini", "prompt"]

    ; ---------------------------------------------------------------------
    ; Upload local configs to a Gist (create or update).
    ; Returns the Gist ID (new or existing).
    ; ---------------------------------------------------------------------
    static Upload(localDir, token, gistId := "") {
        token := Trim(token)
        gistId := Trim(gistId)

        if !DirExist(localDir)
            throw Error(Lang("MSG_GIST_DIR_NOT_FOUND"))

        if token == ""
            throw Error(Lang("MSG_GIST_NO_TOKEN"))

        files := this._CollectFiles(localDir)
        if files.Count == 0
            throw Error(Lang("MSG_GIST_NO_FILES_TO_UPLOAD"))

        ; Build JSON payload using ApiJsonHelper.Escape for safe escaping
        fileParts := []
        for relPath, content in files {
            ; Escape both key and value with the same function used elsewhere
            escapedKey := ApiJsonHelper.Escape(relPath)
            escapedContent := ApiJsonHelper.Escape(content)
            fileParts.Push(escapedKey . ':{' . '"content":' . escapedContent . '}')
        }

        ; Join all file entries
        json := '{"files":{' . Join(fileParts, ",") . '}}'

        url := this.API_BASE "/gists"
        method := "POST"
        if gistId != "" {
            url .= "/" . gistId
            method := "PATCH"
        }

        whr := this._http
        whr.Open(method, url, true)
        whr.SetRequestHeader("Authorization", "token " . token)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetTimeouts(30000, 30000, 30000, 30000)
        whr.Send(json)
        whr.WaitForResponse()

        status := whr.Status
        if status < 200 || status >= 300
            throw Error(Lang("MSG_GIST_HTTP_ERROR", , status, this._Truncate(whr.ResponseText)))

        response := whr.ResponseText
        if gistId == "" {
            if RegExMatch(response, '"id"\s*:\s*"([^"]+)"', &m)
                return m[1]
            throw Error(Lang("MSG_GIST_NO_ID_IN_RESPONSE"))
        }
        return gistId
    }

    ; ---------------------------------------------------------------------
    ; Download Gist content and write it to localDir.
    ; mode: "append" (skip existing) or "overwrite" (replace all).
    ; Returns the number of files written.
    ; ---------------------------------------------------------------------
    static Download(gistId, token, localDir, mode) {
        if token == ""
            throw Error(Lang("MSG_GIST_NO_TOKEN"))

        if gistId == ""
            throw Error(Lang("MSG_GIST_NO_GISTID"))

        whr := this._http
        whr.Open("GET", this.API_BASE "/gists/" . gistId, true)
        whr.SetRequestHeader("Authorization", "token " . token)
        whr.SetTimeouts(30000, 30000, 30000, 30000)
        whr.Send()
        whr.WaitForResponse()

        status := whr.Status
        if status != 200
            throw Error(Lang("MSG_GIST_HTTP_ERROR", , status, this._Truncate(whr.ResponseText)))

        files := this._ParseFiles(whr.ResponseText)
        if files.Count == 0
            throw Error(Lang("MSG_GIST_EMPTY_GIST"))

        if !DirExist(localDir)
            DirCreate(localDir)

        written := 0
        for relPath, content in files {
            fullPath := localDir "\" relPath
            SplitPath(fullPath, , &dir)
            if !DirExist(dir)
                DirCreate(dir)

            if mode == "append" && FileExist(fullPath)
                continue

            FileAppend(content, fullPath, "UTF-8")
            written++
        }
        return written
    }

    ; ---------------------------------------------------------------------
    ; Private helpers
    ; ---------------------------------------------------------------------
    static _CollectFiles(dir) {
        dir := RTrim(dir, "\/")
        files := Map()
        Loop Files, dir "\*", "FR" {
            if InStr(FileExist(A_LoopFileFullPath), "D")
                continue

            SplitPath(A_LoopFileFullPath, , , &ext)
            if !InStr("|" . this.ValidExts . "|", "|" . ext . "|")
                continue

            relPath := SubStr(A_LoopFileFullPath, StrLen(dir) + 2)
            relPath := StrReplace(relPath, "\", "/")
            try {
                content := FileRead(A_LoopFileFullPath, "UTF-8")
                files[relPath] := content
            }
        }
        return files
    }

    ; Parse the "files" object from the Gist API response.
    ; Uses simple regex to extract each filename and its content.
    static _ParseFiles(json) {
        result := Map()
        pos := 1
        while RegExMatch(json, '"([^"]+)"\s*:\s*\{[^}]*"content"\s*:\s*"((?:[^"\\]|\\.)*)"', &m, pos) {
            filename := m[1]
            content := m[2]
            ; Unescape JSON content (only basic unescaping)
            content := StrReplace(content, '\"', '"')
            content := StrReplace(content, '\\', '\')
            content := StrReplace(content, '\n', '`n')
            content := StrReplace(content, '\r', '`r')
            content := StrReplace(content, '\t', '`t')
            result[filename] := content
            pos := m.Pos + m.Len
        }
        return result
    }

    static _Truncate(text, maxLen := 500) {
        if StrLen(text) <= maxLen
            return text
        return SubStr(text, 1, maxLen) . "…"
    }
}
