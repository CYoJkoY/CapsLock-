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
