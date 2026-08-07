#Requires AutoHotkey v2.0

; HTTP client for OpenAI-compatible chat completions API.
; Supports any API endpoint that follows the OpenAI chat completions format.
class ApiClient {
    ; Send a chat completion request and return the assistant's response text.
    ; Throws an exception with a localized error message on failure.
    ;
    ; Parameters:
    ;   systemPrompt - The system message (prompt instructions)
    ;   userContent  - The user message (clipboard content)
    ;
    ; Returns: The assistant's response text.
    static Send(systemPrompt, userContent) {
        ; Auto-append /chat/completions if user only provided the base URL
        url := AppState.ApiUrl
        if (url != "" && !RegExMatch(url, "i)/chat/completions$"))
            url := RTrim(url, "/") . "/chat/completions"

        key := AppState.ApiKey
        model := AppState.ApiModel
        maxTokens := AppState.ApiMaxTokens
        temperature := AppState.ApiTemperature

        ; Validate configuration
        if (url == "") {
            throw Error(Lang("MSG_API_URL_NOT_SET"))
        }
        if (key == "") {
            throw Error(Lang("MSG_API_KEY_NOT_SET"))
        }

        ; Build JSON request body
        body := this._BuildRequestBody(systemPrompt, userContent, model, maxTokens, temperature)

        ; Create and configure HTTP request
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", url, true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("Authorization", "Bearer " . key)
        whr.SetTimeouts(60000, 60000, 60000, 60000)  ; 60 second timeouts

        ; Send request
        try {
            whr.Send(body)
            whr.WaitForResponse()
        } catch as err {
            throw Error(Lang("MSG_API_REQUEST_FAILED", "API request failed: {1}", err.Message))
        }

        ; Check HTTP status
        status := whr.Status
        if (status != 200) {
            errorMsg := this._ParseErrorResponse(whr.ResponseText)
            throw Error(Lang("MSG_API_ERROR", "API error (HTTP {1}): {2}", status, errorMsg))
        }

        ; Parse successful response
        return this._ParseResponse(whr.ResponseText)
    }

    ; Test the API connection with a simple request.
    ; Returns true on success, throws on failure.
    static TestConnection() {
        ; Send a minimal test message
        response := this.Send("You are a helpful assistant. Reply with just 'OK'.", "ping")
        return response != ""
    }

    ; --- Private methods ---

    ; Build the JSON request body for the chat completions endpoint.
    static _BuildRequestBody(systemPrompt, userContent, model, maxTokens, temperature) {
        ; Manually construct JSON to avoid external dependencies.
        ; Order: model, messages array, max_tokens, temperature
        json := '{'
        json .= '"model":' . this._JsonValue(model) . ','
        json .= '"messages":['
        json .= '{"role":"system","content":' . this._JsonValue(systemPrompt) . '},'
        json .= '{"role":"user","content":' . this._JsonValue(userContent) . '}'
        json .= '],'
        json .= '"max_tokens":' . maxTokens . ','
        json .= '"temperature":' . temperature
        json .= '}'

        return json
    }

    ; Parse the successful API response to extract the assistant's message content.
    ; Handles the standard OpenAI response format: choices[0].message.content
    static _ParseResponse(responseText) {
        ; Extract all "content" values from the response.
        ; The assistant's response is the last content field in the choices array.
        ; We search for patterns like: "content":"..."
        ; and handle JSON escape sequences within the content string.

        contents := []
        searchPos := 1
        marker := '"content":"'

        while searchPos := InStr(responseText, marker, , searchPos) {
            searchPos += StrLen(marker)
            content := ""

            while searchPos <= StrLen(responseText) {
                ch := SubStr(responseText, searchPos, 1)

                if ch == '\' && searchPos + 1 <= StrLen(responseText) {
                    ; Handle JSON escape sequences
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
                            ; Unicode escape \uXXXX - extract 4 hex digits
                            if searchPos + 3 <= StrLen(responseText) {
                                hexStr := SubStr(responseText, searchPos, 4)
                                searchPos += 4
                                ; Only handle basic ASCII-range unicode escapes
                                try {
                                    codePoint := Integer("0x" . hexStr)
                                    if codePoint <= 0x7F
                                        content .= Chr(codePoint)
                                    else
                                        content .= "?"
                                } catch {
                                    content .= "?"
                                }
                            }
                        default:
                            content .= nextCh
                    }
                } else if ch == '"' {
                    ; End of string found
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

        ; Return the last content value (should be the assistant's message)
        return contents[contents.Length]
    }

    ; Parse error response from API to extract a readable error message.
    static _ParseErrorResponse(responseText) {
        ; Try to extract the error message from JSON like:
        ; {"error":{"message":"...","type":"...","code":"..."}}

        if RegExMatch(responseText, '"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
            msg := m[1]
            ; Unescape basic JSON escapes
            msg := StrReplace(msg, "\n", "`n")
            msg := StrReplace(msg, '"', '"')
            msg := StrReplace(msg, "\\", "\")
            msg := StrReplace(msg, "\/", "/")
            return msg
        }

        ; Fallback: return first 200 characters of response
        return SubStr(responseText, 1, 200)
    }

    ; Escape a string value for inclusion in JSON.
    ; Handles: backslash, double-quote, newline, carriage return, tab,
    ; and strips control characters that are invalid in JSON strings.
    static _JsonValue(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        ; Strip control characters (except the ones we already escaped)
        str := RegExReplace(str, "[\x00-\x08\x0B\x0C\x0E-\x1F]", "")
        return '"' . str . '"'
    }
}
