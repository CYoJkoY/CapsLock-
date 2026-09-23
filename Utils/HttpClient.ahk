#Requires AutoHotkey v2.0

class HttpClient {
    static Request(method, url, headers := "", body := "", timeout := 15000) {
        request := ComObject("WinHttp.WinHttpRequest.5.1")
        request.SetTimeouts(timeout, timeout, timeout, timeout)
        request.Open(method, url, false)

        if IsObject(headers) {
            for name, value in headers
                request.SetRequestHeader(name, value)
        }

        request.Send(body)

        responseHeaders := ""
        try responseHeaders := request.GetAllResponseHeaders()

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
