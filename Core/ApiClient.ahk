#Requires AutoHotkey v2.0

; Main HTTP client for OpenAI-compatible chat completions API.
; Routes requests to either classic or streaming handlers based on mode.
class ApiClient {
    ; Send a request. If stream mode and callback provided, use streaming.
    static Send(systemPrompt, userContent, callback := unset) {
        if AppState.ApiStreamMode && IsSet(callback) && IsObject(callback) {
            return ApiStreamHandler.SendStream(systemPrompt, userContent, callback)
        }
        return ApiResponseParser.SendClassic(systemPrompt, userContent)
    }

    ; Test the API connection by sending a simple ping.
    static TestConnection() {
        response := this.Send("You are a helpful assistant. Reply with just 'OK'.", "ping")
        return response != ""
    }
}
