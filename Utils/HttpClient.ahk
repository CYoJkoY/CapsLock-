#Requires AutoHotkey v2.0

class HttpClient {
    static Request(method, url, headers := "", body := "", timeout := 15000) {
        request := ComObject("WinHttp.WinHttpRequest.5.1")
        request.SetTimeouts(timeout, timeout, timeout, timeout)
        request.Open(method, url, true)          ; async

        if IsObject(headers) {
            for name, value in headers
                request.SetRequestHeader(name, value)
        }

        request.Send(body)

        ; Keep AHK processing messages while waiting: hotkeys and GUI repaints no longer block
        deadline := A_TickCount + timeout
        while !request.WaitForResponse(0) {
            if A_TickCount > deadline
                throw Error("Cloud Sync request timed out.")
            Sleep(30)
        }

        responseHeaders := ""
        try responseHeaders := request.GetAllResponseHeaders()

        utf8_body := request.ResponseText

        ; No charset means WinHTTP uses the local code page and corrupts UTF-8; use binary
        try {
            arr := request.ResponseBody
            size := arr.MaxIndex() + 1
            buf := Buffer(size, 0)
            Loop size
                buf[A_Index - 1] := arr[A_Index - 1]
            utf8_body := StrGet(buf, size, "UTF-8")
        } catch {
        }

        return {
            status: request.Status,
            statusText: request.StatusText,
            headers: responseHeaders,
            body: request.ResponseText
        }
    }

    static IsSuccess(response) {
        return IsObject(response)
            && response.status >= 200
            && response.status < 300
    }
}


FormUrlEncode(values) {
    result := ""
    for key, value in values {
        if result != ""
            result .= "&"
        result .= UriEncode(String(key)) "=" UriEncode(String(value))
    }
    return result
}


UriEncode(text) {
    text := String(text)
    size := StrPut(text, "UTF-8") - 1
    mybuffer := Buffer(Max(size, 1), 0)
    if size > 0
        StrPut(text, mybuffer, "UTF-8")

    alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    result := ""

    Loop size {
        byte := NumGet(mybuffer, A_Index - 1, "UChar")
        ch := Chr(byte)

        if InStr(alphabet, ch)
            result .= ch
        else
            result .= "%" Format("{:02X}", byte)
    }

    return result
}

UriEncodePath(text) {
    segments := StrSplit(String(text), "/")
    encoded := ""

    for segment in segments {
        if encoded != ""
            encoded .= "/"
        encoded .= UriEncode(segment)
    }

    return encoded
}
