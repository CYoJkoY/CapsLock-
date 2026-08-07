#Requires AutoHotkey v2.0

; HTTP client for OpenAI-compatible chat completions API.
; Supports any API endpoint that follows the OpenAI chat completions format.
class ApiClient {

    ; ------------------------------------------------------------------------
    ; Send a request. If stream mode is enabled and a callback is provided,
    ; it will stream the response chunks to the callback.
    ; Otherwise, it returns the full response as a string.
    ; ------------------------------------------------------------------------
    static Send(systemPrompt, userContent, callback := unset) {
        if AppState.ApiStreamMode && IsSet(callback) && IsObject(callback) {
            return this._SendStream(systemPrompt, userContent, callback)
        }
        return this._SendClassic(systemPrompt, userContent)
    }

    ; ------------------------------------------------------------------------
    ; Classic (non‑streaming) request – returns the full response.
    ; ------------------------------------------------------------------------
    static _SendClassic(systemPrompt, userContent) {
        url := AppState.ApiUrl
        if (url != "" && !RegExMatch(url, "i)/chat/completions$"))
            url := RTrim(url, "/") . "/chat/completions"

        key := AppState.ApiKey
        model := AppState.ApiModel
        maxTokens := AppState.ApiMaxTokens
        temperature := AppState.ApiTemperature

        if (url == "") {
            throw Error(Lang("MSG_API_URL_NOT_SET"))
        }
        if (key == "") {
            throw Error(Lang("MSG_API_KEY_NOT_SET"))
        }

        body := this._BuildRequestBody(systemPrompt, userContent, model, maxTokens, temperature, false)

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", url, true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("Authorization", "Bearer " . key)
        whr.SetTimeouts(60000, 60000, 60000, 60000)

        try {
            whr.Send(body)
            whr.WaitForResponse()
        } catch as err {
            throw Error(Lang("MSG_API_REQUEST_FAILED", "API request failed: {1}", err.Message))
        }

        status := whr.Status
        if (status != 200) {
            errorMsg := this._ParseErrorResponse(whr.ResponseText)
            throw Error(Lang("MSG_API_ERROR", "API error (HTTP {1}): {2}", status, errorMsg))
        }

        return this._ParseResponse(whr.ResponseText)
    }

    ; ----------------------------------------------------------------------------
    ; Streaming request using curl via a temporary batch file.
    ; Uses robust SSE parsing with multi-line support and generic content extraction.
    ; ----------------------------------------------------------------------------
    static _SendStream(systemPrompt, userContent, callback) {
        url := AppState.ApiUrl
        if (url != "" && !RegExMatch(url, "i)/chat/completions$"))
            url := RTrim(url, "/") . "/chat/completions"

        key := AppState.ApiKey
        if (url == "" || key == "")
            throw Error(Lang("MSG_API_URL_NOT_SET", "API URL or key missing"))

        body := this._BuildRequestBody(systemPrompt, userContent, AppState.ApiModel,
                                        AppState.ApiMaxTokens, AppState.ApiTemperature, true)

        tempBody := A_Temp "\curl_body_" A_TickCount ".json"
        try FileDelete(tempBody)
        FileAppend(body, tempBody, "UTF-8")

        dq := Chr(34)
        cmd := "curl -X POST -N -s --no-buffer"
            . " -H " . dq . "Content-Type: application/json" . dq
            . " -H " . dq . "Authorization: Bearer " . key . dq
            . " -d @" . dq . tempBody . dq
            . " " . dq . url . dq

        batFile := A_Temp "\curl_stream_" A_TickCount ".bat"
        try FileDelete(batFile)
        FileAppend("@echo off`n@" cmd "`n", batFile, "UTF-8")

        ; === DEBUG: Log command and start ===
        debugLog := A_Temp "\curl_debug_" A_TickCount ".txt"
        FileAppend("=== CURL COMMAND ===`n" cmd "`n`n", debugLog, "UTF-8")
        FileAppend("=== BATCH FILE CONTENT ===`n" "@" cmd "`n`n", debugLog, "UTF-8")
        FileAppend("=== RAW OUTPUT START ===`n", debugLog, "UTF-8")

        shell := ComObject("WScript.Shell")
        exec := shell.Exec(batFile)
        fullContent := ""
        dataBuffer := ""

        ; Read stdout and log every line
        while !exec.StdOut.AtEndOfStream {
            line := exec.StdOut.ReadLine()
            FileAppend("RAW: " line "`n", debugLog, "UTF-8")   ; log raw line

            line := Trim(line)
            if (line == "") {
                if (dataBuffer != "") {
                    dataPart := Trim(SubStr(dataBuffer, 6))
                    if (dataPart != "[DONE]") {
                        text := this._ExtractContent(dataPart)
                        if (text != "") {
                            fullContent .= text
                            try callback.Call(text)
                        }
                    }
                    dataBuffer := ""
                }
                continue
            }
            if (SubStr(line, 1, 5) == "data:") {
                if (dataBuffer != "") {
                    dataPart := Trim(SubStr(dataBuffer, 6))
                    if (dataPart != "[DONE]") {
                        text := this._ExtractContent(dataPart)
                        if (text != "") {
                            fullContent .= text
                            try callback.Call(text)
                        }
                    }
                }
                dataBuffer := line
            } else {
                if (dataBuffer != "")
                    dataBuffer .= "`n" . line
            }
        }

        ; Flush remaining buffer
        if (dataBuffer != "") {
            dataPart := Trim(SubStr(dataBuffer, 6))
            if (dataPart != "[DONE]") {
                text := this._ExtractContent(dataPart)
                if (text != "")
                    fullContent .= text
            }
        }

        ; Read stderr for errors
        while !exec.StdErr.AtEndOfStream {
            errLine := exec.StdErr.ReadLine()
            FileAppend("STDERR: " errLine "`n", debugLog, "UTF-8")
        }

        FileAppend("=== RAW OUTPUT END ===`n", debugLog, "UTF-8")
        ; === DEBUG END ===

        try FileDelete(tempBody)
        try FileDelete(batFile)
        return fullContent
    }

    ; ----------------------------------------------------------------------------
    ; Extract the value of the "content" field from a JSON string (any nesting).
    ; Handles escape sequences and Unicode escapes.
    ; ----------------------------------------------------------------------------
    static _ExtractContent(dataPart) {
        ; Find the position of "content":
        pos := InStr(dataPart, '"content":')
        if !pos
            return ""
        pos += 10   ; skip over '"content":'
        ; Skip whitespace
        while SubStr(dataPart, pos, 1) == " " || SubStr(dataPart, pos, 1) == "`t"
            pos++
        if SubStr(dataPart, pos, 1) != '"'
            return ""
        pos++   ; skip opening quote
        content := ""
        len := StrLen(dataPart)
        while pos <= len {
            ch := SubStr(dataPart, pos, 1)
            if ch == '\' {   ; escape sequence
                pos++
                if pos > len
                    break
                nextCh := SubStr(dataPart, pos, 1)
                switch nextCh {
                    case 'n':  content .= "`n"
                    case 'r':  content .= "`r"
                    case 't':  content .= "`t"
                    case '"':  content .= '"'
                    case '\\': content .= "\"
                    case '/':  content .= "/"
                    case 'u':  ; Unicode escape
                        if pos + 4 <= len {
                            hexStr := SubStr(dataPart, pos + 1, 4)
                            pos += 4
                            try content .= Chr(Integer("0x" . hexStr))
                            catch 
                                content .= "?"
                        }
                    default:   content .= nextCh
                }
                pos++
                continue
            }
            if ch == '"' {   ; closing quote – end of content
                pos++
                break
            }
            content .= ch
            pos++
        }
        return content
    }

    ; ------------------------------------------------------------------------
    ; Nested event sink for streaming responses.
    ; ------------------------------------------------------------------------
    class _StreamSink {
        __New(callback) {
            this.callback := callback
            this._buffer := ""
            this._fullContent := ""
            this._complete := false
            this._httpStatus := 0
            this._errorMsg := ""
            this._inData := false
            this._dataBuffer := ""
        }

        OnResponseDataAvailable(Data) {
            try {
                pData := NumGet(ComObjValue(Data) + 4 + A_PtrSize, "Ptr")
                size := Data.MaxIndex() + 1
                if (size > 0) {
                    buf := Buffer(size)
                    DllCall("RtlMoveMemory", "Ptr", buf.Ptr, "Ptr", pData, "Ptr", size)
                    chunk := StrGet(buf, size, "UTF-8")
                    this._buffer .= chunk
                    this._ProcessBuffer()
                }
            } catch {
                ; ignore
            }
        }

        OnResponseStart(Status, ContentType) {
            this._httpStatus := Status
        }

        OnResponseCompleted() {
            this._ProcessBuffer()
            this._complete := true
        }

        OnError(ErrorNumber, ErrorDescription) {
            this._errorMsg := ErrorDescription
            this._complete := true
        }

        _ProcessBuffer() {
            while (pos := InStr(this._buffer, "`n")) {
                line := SubStr(this._buffer, 1, pos - 1)
                this._buffer := SubStr(this._buffer, pos + 1)

                if (line == "") {
                    if (this._inData) {
                        this._inData := false
                        this._HandleEvent(this._dataBuffer)
                        this._dataBuffer := ""
                    }
                    continue
                }

                if (SubStr(line, 1, 5) == "data:") {
                    this._inData := true
                    dataPart := Trim(SubStr(line, 6))
                    if (dataPart == "[DONE]") {
                        this._inData := false
                        this._dataBuffer := ""
                        continue
                    }
                    if (this._dataBuffer != "")
                        this._dataBuffer .= "`n"
                    this._dataBuffer .= dataPart
                }
            }
        }

        _HandleEvent(data) {
            ; Extract from delta.content (streaming) first
            if RegExMatch(data, '"delta":\s*\{[^}]*"content":\s*"((?:[^"\\]|\\.)*)"', &m) {
                text := this._UnescapeJson(m[1])
                if (text != "") {
                    this._fullContent .= text
                    try this.callback.Call(text)
                }
                return
            }

            ; Fallback for non-delta format (classic)
            if RegExMatch(data, '"content":\s*"((?:[^"\\]|\\.)*)"', &m) {
                text := this._UnescapeJson(m[1])
                if (text != "") {
                    this._fullContent .= text
                    try this.callback.Call(text)
                }
            }
        }

        _UnescapeJson(str) {
            str := StrReplace(str, "\n", "`n")
            str := StrReplace(str, "\r", "`r")
            str := StrReplace(str, "\t", "`t")
            str := StrReplace(str, '\"', '"')
            str := StrReplace(str, "\\", "\")
            return str
        }
    }

    ; ------------------------------------------------------------------------
    ; Build JSON request body. The `stream` parameter toggles streaming.
    ; ------------------------------------------------------------------------
    static _BuildRequestBody(systemPrompt, userContent, model, maxTokens, temperature, stream) {
        json := '{'
        json .= '"model":' . this._JsonValue(model) . ','
        json .= '"messages":['
        json .= '{"role":"system","content":' . this._JsonValue(systemPrompt) . '},'
        json .= '{"role":"user","content":' . this._JsonValue(userContent) . '}'
        json .= '],'
        json .= '"max_tokens":' . maxTokens . ','
        json .= '"temperature":' . temperature . ','
        json .= '"stream":' . (stream ? "true" : "false")
        json .= '}'
        return json
    }

    ; ------------------------------------------------------------------------
    ; Parse full (non‑streaming) response – now fully Unicode‑compliant.
    ; ------------------------------------------------------------------------
    static _ParseResponse(responseText) {
        contents := []
        searchPos := 1
        marker := '"content":"'

        while searchPos := InStr(responseText, marker, , searchPos) {
            searchPos += StrLen(marker)
            content := ""

            while searchPos <= StrLen(responseText) {
                ch := SubStr(responseText, searchPos, 1)

                if ch == '\' && searchPos + 1 <= StrLen(responseText) {
                    nextCh := SubStr(responseText, searchPos + 1, 1)
                    searchPos += 2

                    switch nextCh {
                        case 'n':  content .= "`n"
                        case 'r':  content .= "`r"
                        case 't':  content .= "`t"
                        case '"':  content .= '"'
                        case '\\': content .= "\"
                        case '/':  content .= "/"
                        case 'u':
                            if searchPos + 3 <= StrLen(responseText) {
                                hexStr := SubStr(responseText, searchPos, 4)
                                searchPos += 4
                                try {
                                    codePoint := Integer("0x" . hexStr)
                                    content .= Chr(codePoint)   ; <--- fixed: any valid Unicode
                                } catch {
                                    content .= "?"
                                }
                            }
                        default:
                            content .= nextCh
                    }
                } else if ch == '"' {
                    searchPos++
                    break
                } else {
                    content .= ch
                    searchPos++
                }
            }

            if content != ""
                contents.Push(content)
        }

        if contents.Length == 0 {
            throw Error(Lang("MSG_API_PARSE_ERROR", "Failed to parse API response. No content found."))
        }

        return contents[contents.Length]
    }

    ; ------------------------------------------------------------------------
    ; Parse error response (unchanged)
    ; ------------------------------------------------------------------------
    static _ParseErrorResponse(responseText) {
        if RegExMatch(responseText, '"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
            msg := m[1]
            msg := StrReplace(msg, "\n", "`n")
            msg := StrReplace(msg, '"', '"')
            msg := StrReplace(msg, "\\", "\")
            msg := StrReplace(msg, "\/", "/")
            return msg
        }
        return SubStr(responseText, 1, 200)
    }

    ; ------------------------------------------------------------------------
    ; JSON string escaper (unchanged)
    ; ------------------------------------------------------------------------
    static _JsonValue(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        str := RegExReplace(str, "[\x00-\x08\x0B\x0C\x0E-\x1F]", "")
        return '"' . str . '"'
    }

    ; ------------------------------------------------------------------------
    ; Test connection (unchanged)
    ; ------------------------------------------------------------------------
    static TestConnection() {
        response := this.Send("You are a helpful assistant. Reply with just 'OK'.", "ping")
        return response != ""
    }
}
