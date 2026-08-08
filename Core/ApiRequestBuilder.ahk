#Requires AutoHotkey v2.0

; Builds JSON request bodies for OpenAI-compatible chat completions API.
class ApiRequestBuilder {
    ; Build the full JSON request body.
    static BuildRequestBody(systemPrompt, userContent, model, maxTokens, temperature, stream) {
        json := '{'
        json .= '"model":' . ApiJsonHelper.Escape(model) . ','
        json .= '"messages":['
        json .= '{"role":"system","content":' . ApiJsonHelper.Escape(systemPrompt) . '},'
        json .= '{"role":"user","content":' . ApiJsonHelper.Escape(userContent) . '}'
        json .= '],'
        json .= '"max_tokens":' . maxTokens . ','
        json .= '"temperature":' . temperature . ','
        json .= '"stream":' . (stream ? "true" : "false")
        json .= '}'
        return json
    }
}
