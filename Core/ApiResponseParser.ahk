#Requires AutoHotkey v2.0

; Handles classic (non-streaming) API requests and response parsing.
class ApiResponseParser {
    ; Send a classic request and return the full response content.
    static SendClassic(systemPrompt, userContent) {
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

        body := ApiRequestBuilder.BuildRequestBody(systemPrompt, userContent, model, maxTokens, temperature, false)

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

    ; Parse the full response JSON and extract the last content.
    static _ParseResponse(responseText) {
        contents := []
        searchPos := 1
        marker := '"content":"'
        while searchPos := InStr(responseText, marker, , searchPos) {
            searchPos += StrLen(marker)
            startPos := searchPos

            ; Find the closing quote considering escapes.
            while searchPos <= StrLen(responseText) {
                ch := SubStr(responseText, searchPos, 1)
                if (ch == "`"" && SubStr(responseText, searchPos-1, 1) != "\") {
                    break
                }

                searchPos++
            }
            if (searchPos > startPos) {
                raw := SubStr(responseText, startPos, searchPos - startPos)
                content := ApiJsonHelper.Unescape(raw)
                if (content != "")
                    contents.Push(content)
            }
            searchPos++ ; skip the closing quote
        }
        if (contents.Length == 0) {
            throw Error(Lang("MSG_API_PARSE_ERROR", "Failed to parse API response. No content found."))
        }
        return contents[contents.Length]
    }

    ; Parse error message from API error response.
    static _ParseErrorResponse(responseText) {
        if RegExMatch(responseText, '"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
            msg := m[1]
            msg := ApiJsonHelper.Unescape(msg)
            return msg
        }
        return SubStr(responseText, 1, 200)
    }
}
