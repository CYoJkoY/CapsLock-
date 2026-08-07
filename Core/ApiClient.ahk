#Requires AutoHotkey v2.0

; HTTP client for OpenAI-compatible chat completions API.
; Supports any API endpoint that follows the OpenAI chat completions format.
class ApiClient {

    ; Static members for streaming process management
    static _streamPid := 0
    static _streamOutputFile := ""
    static _streamTimer := ""
    static _streamCallback := ""
    static _streamLastPos := 0
    static _streamFullContent := ""
    static _streamComplete := false

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
    ; Streaming request using curl via Run hidden + file polling.
    ; No console window appears, and the main thread remains responsive.
    ; ----------------------------------------------------------------------------
    static _SendStream(systemPrompt, userContent, callback) {
        ; Cancel any existing streaming process
        this._CancelStream()

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

        ; Create a temporary output file for curl's stdout/stderr
        outputFile := A_Temp "\curl_output_" A_TickCount ".txt"
        this._streamOutputFile := outputFile
        this._streamLastPos := 0
        this._streamFullContent := ""
        this._streamCallback := callback
        this._streamComplete := false

        dq := Chr(34)
        cmd := "curl -X POST -N -s --no-buffer"
            . " -H " . dq . "Content-Type: application/json" . dq
            . " -H " . dq . "Authorization: Bearer " . key . dq
            . " -d @" . dq . tempBody . dq
            . " " . dq . url . dq

        ; Redirect stdout and stderr to the output file
        fullCmd := A_ComSpec " /c " cmd . " > " . dq . outputFile . dq . " 2>&1"

        try {
            ; Run hidden, get PID
            Run(fullCmd, , "Hide", &pid)
            this._streamPid := pid

            ; Start polling timer (every 50 ms)
            this._streamTimer := ObjBindMethod(this, "_StreamPoll")
            SetTimer(this._streamTimer, 50)

            ; Note: We return immediately; the callback will receive chunks as they arrive.
            ; The final full content is not returned; UI window holds the content.
            return ""
        } catch as err {
            try FileDelete(tempBody)
            try FileDelete(outputFile)
            throw Error(Lang("MSG_API_REQUEST_FAILED", "Failed to start curl: {1}", err.Message))
        }
    }

    ; ----------------------------------------------------------------------------
    ; Poll the output file for new data and feed it to the callback.
    ; Called periodically by a timer.
    ; ----------------------------------------------------------------------------
    static _StreamPoll() {
        if (this._streamOutputFile == "")
            return

        ; Check if the process is still running
        if (this._streamPid && !ProcessExist(this._streamPid)) {
            ; Process ended, read all remaining data and clean up
            this._streamComplete := true
            this._ReadRemaining()
            this._CleanupStream()
            return
        }

        ; Read new data from the file
        this._ReadRemaining()
    }

    ; ----------------------------------------------------------------------------
    ; Read the portion of the output file that hasn't been read yet.
    ; ----------------------------------------------------------------------------
    static _ReadRemaining() {
        if (this._streamOutputFile == "" || !FileExist(this._streamOutputFile))
            return

        try {
            ; Get current file size
            fileSize := FileGetSize(this._streamOutputFile)
            if (fileSize <= this._streamLastPos)
                return

            ; Read the new portion
            myfile := FileOpen(this._streamOutputFile, "r", "UTF-8")
            if !IsObject(myfile)
                return

            ; Seek to last read position (seek from beginning)
            myfile.Seek(this._streamLastPos, 0)

            ; Read the whole new portion
            newData := myfile.Read(fileSize - this._streamLastPos)
            myfile.Close()

            this._streamLastPos := fileSize

            ; Process the new data line by line (SSE events)
            if (newData != "") {
                this._ProcessStreamData(newData)
            }
        } catch {
            ; Ignore read errors
        }
    }

    ; ----------------------------------------------------------------------------
    ; Process raw SSE data: split by lines and extract content.
    ; ----------------------------------------------------------------------------
    static _ProcessStreamData(rawData) {
        static buffer := ""
        buffer .= rawData

        ; Split by newline
        lines := StrSplit(buffer, "`n")
        ; Keep the last incomplete line in buffer
        if (SubStr(buffer, -1) != "`n") {
            buffer := lines.Pop()
        } else {
            buffer := ""
        }

        for line in lines {
            line := Trim(line)
            if (line == "") {
                ; Empty line may indicate end of an event, but we ignore it
                continue
            }
            if (SubStr(line, 1, 5) == "data:") {
                dataPart := Trim(SubStr(line, 6))
                if (dataPart == "[DONE]") {
                    this._streamComplete := true
                    continue
                }
                ; Extract content from the JSON
                text := this._ExtractContent(dataPart)
                if (text != "") {
                    this._streamFullContent .= text
                    try this._streamCallback.Call(text)
                }
            }
        }
    }

    ; ----------------------------------------------------------------------------
    ; Clean up streaming resources (timer, file, process).
    ; ----------------------------------------------------------------------------
    static _CleanupStream() {
        if (this._streamTimer != "") {
            SetTimer(this._streamTimer, 0)
            this._streamTimer := ""
        }

        if (this._streamPid) {
            try ProcessClose(this._streamPid)
            this._streamPid := 0
        }

        if (this._streamOutputFile != "") {
            try FileDelete(this._streamOutputFile)
            this._streamOutputFile := ""
        }

        this._streamCallback := ""
        this._streamLastPos := 0
        this._streamFullContent := ""
        this._streamComplete := false
    }

    ; ----------------------------------------------------------------------------
    ; Cancel the currently running streaming request (if any).
    ; ----------------------------------------------------------------------------
    static _CancelStream() {
        if (this._streamPid) {
            try ProcessClose(this._streamPid)
            this._streamPid := 0
        }
        this._CleanupStream()
    }

    ; ----------------------------------------------------------------------------
    ; Extract the "content" field from a JSON chunk.
    ; (Same as before, kept for compatibility)
    ; ----------------------------------------------------------------------------
    static _ExtractContent(dataPart) {
        pos := InStr(dataPart, '"content":')
        if !pos
            return ""
        pos += 10
        while SubStr(dataPart, pos, 1) == " " || SubStr(dataPart, pos, 1) == "`t"
            pos++
        if SubStr(dataPart, pos, 1) != '"'
            return ""
        pos++
        content := ""
        len := StrLen(dataPart)
        while pos <= len {
            ch := SubStr(dataPart, pos, 1)
            if ch == '\' {
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
                    case 'u':
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
            if ch == '"' {
                pos++
                break
            }
            content .= ch
            pos++
        }
        return content
    }

    ; ------------------------------------------------------------------------
    ; Build JSON request body (unchanged).
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
    ; Parse full (non‑streaming) response (unchanged).
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
                                    content .= Chr(codePoint)
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
    ; Parse error response (unchanged).
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
    ; JSON string escaper (unchanged).
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
    ; Test connection (unchanged).
    ; ------------------------------------------------------------------------
    static TestConnection() {
        response := this.Send("You are a helpful assistant. Reply with just 'OK'.", "ping")
        return response != ""
    }
}
