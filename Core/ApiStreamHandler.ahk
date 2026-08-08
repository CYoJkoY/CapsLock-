#Requires AutoHotkey v2.0

; Handles streaming API requests using curl and file polling.
class ApiStreamHandler {
    static _pid := 0
    static _outputFile := ""
    static _timer := ""
    static _callback := ""
    static _lastPos := 0
    static _fullContent := ""
    static _complete := false
    static _bodyFile := ""  ; track body file for cleanup

    ; Send a streaming request. The callback receives each content chunk.
    static SendStream(systemPrompt, userContent, callback) {
        ; Cancel any existing stream
        this._CancelStream()

        url := AppState.ApiUrl
        if (url != "" && !RegExMatch(url, "i)/chat/completions$"))
            url := RTrim(url, "/") . "/chat/completions"

        key := AppState.ApiKey
        if (url == "" || key == "")
            throw Error(Lang("MSG_API_URL_NOT_SET", "API URL or key missing"))

        body := ApiRequestBuilder.BuildRequestBody(
            systemPrompt, userContent,
            AppState.ApiModel, AppState.ApiMaxTokens, AppState.ApiTemperature, true
        )

        ; Create temporary files
        tempBody := A_Temp "\curl_body_" A_TickCount ".json"
        try FileDelete(tempBody)
        FileAppend(body, tempBody, "UTF-8")
        this._bodyFile := tempBody

        outputFile := A_Temp "\curl_output_" A_TickCount ".txt"
        this._outputFile := outputFile
        this._lastPos := 0
        this._fullContent := ""
        this._callback := callback
        this._complete := false

        dq := Chr(34)
        cmd := "curl -X POST -N -s --no-buffer"
            . " -H " . dq . "Content-Type: application/json" . dq
            . " -H " . dq . "Authorization: Bearer " . key . dq
            . " -d @" . dq . tempBody . dq
            . " " . dq . url . dq

        fullCmd := A_ComSpec " /c " . cmd . " > " . dq . outputFile . dq . " 2>&1"

        try {
            Run(fullCmd, , "Hide", &pid)
            this._pid := pid

            ; Start polling timer
            this._timer := ObjBindMethod(this, "_Poll")
            SetTimer(this._timer, 50)

            return ""
        } catch as err {
            try FileDelete(tempBody)
            try FileDelete(outputFile)
            throw Error(Lang("MSG_API_REQUEST_FAILED", "Failed to start curl: {1}", err.Message))
        }
    }

    ; Poll the output file for new data.
    static _Poll() {
        if (this._outputFile == "")
            return

        if (this._pid && !ProcessExist(this._pid)) {
            ; Process ended, read remaining and clean up
            this._complete := true
            this._ReadRemaining()
            this._Cleanup()
            return
        }

        this._ReadRemaining()
    }

    ; Read new data from the output file.
    static _ReadRemaining() {
        if (this._outputFile == "" || !FileExist(this._outputFile))
            return

        try {
            fileSize := FileGetSize(this._outputFile)
            if (fileSize <= this._lastPos)
                return

            myfile := FileOpen(this._outputFile, "r", "UTF-8")
            if !IsObject(myfile)
                return

            myfile.Seek(this._lastPos, 0)
            newData := myfile.Read(fileSize - this._lastPos)
            myfile.Close()

            this._lastPos := fileSize

            if (newData != "") {
                this._ProcessData(newData)
            }
        } catch {
            ; Ignore read errors
        }
    }

    ; Process raw SSE data.
    static _ProcessData(rawData) {
        static buffer := ""
        buffer .= rawData

        lines := StrSplit(buffer, "`n")
        if (SubStr(buffer, -1) != "`n") {
            buffer := lines.Pop()
        } else {
            buffer := ""
        }

        for line in lines {
            line := Trim(line)
            if (line == "")
                continue
            if (SubStr(line, 1, 5) == "data:") {
                dataPart := Trim(SubStr(line, 6))
                if (dataPart == "[DONE]") {
                    this._complete := true
                    continue
                }
                text := this._ExtractContent(dataPart)
                if (text != "") {
                    this._fullContent .= text
                    try this._callback.Call(text)
                }
            }
        }
    }

    ; Extract content from a JSON data chunk.
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
        start := pos
        ; Find the closing quote considering escapes.
        len := StrLen(dataPart)
        while pos <= len {
            ch := SubStr(dataPart, pos, 1)
            if (ch == "`"" && SubStr(dataPart, pos-1, 1) != "\") {
                break
            }

            pos++
        }
        if (pos > start) {
            raw := SubStr(dataPart, start, pos - start)
            return ApiJsonHelper.Unescape(raw)
        }

        return ""
    }

    ; Clean up resources.
    static _Cleanup() {
        if (this._timer != "") {
            SetTimer(this._timer, 0)
            this._timer := ""
        }

        if (this._pid) {
            try ProcessClose(this._pid)
            this._pid := 0
        }

        if (this._outputFile != "") {
            try FileDelete(this._outputFile)
            this._outputFile := ""
        }

        if (this._bodyFile != "") {
            try FileDelete(this._bodyFile)
            this._bodyFile := ""
        }

        this._callback := ""
        this._lastPos := 0
        this._fullContent := ""
        this._complete := false
    }

    ; Cancel the current stream.
    static _CancelStream() {
        if (this._pid) {
            try ProcessClose(this._pid)
            this._pid := 0
        }
        this._Cleanup()
    }
}
