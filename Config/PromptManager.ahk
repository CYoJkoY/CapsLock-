#Requires AutoHotkey v2.0

; Manages AI prompts: load, save, add, update, delete, and track the active prompt.
; Prompts are stored as a JSON file in the configs directory.
class PromptManager {
    static Prompts := []          ; Array of {name, content}
    static ActivePrompt := ""     ; Name of the currently active prompt
    static PromptsFile := A_ScriptDir "\configs\Prompts.json"

    ; Load prompts from JSON file. Creates file with defaults if it doesn't exist.
    static Load() {
        if !FileExist(this.PromptsFile) {
            this._CreateDefault()
            return
        }

        try {
            raw := FileRead(this.PromptsFile, "UTF-8")
            data := this._ParseJson(raw)

            if data.Has("active")
                this.ActivePrompt := data["active"]

            if data.Has("prompts") && IsObject(data["prompts"]) {
                this.Prompts := []
                for entry in data["prompts"] {
                    if entry.Has("name") && entry.Has("content") {
                        this.Prompts.Push({
                            name: entry["name"],
                            content: entry["content"]
                        })
                    }
                }
            }

            ; Validate active prompt still exists
            if this.ActivePrompt != "" && !this.FindByName(this.ActivePrompt) {
                this.ActivePrompt := (this.Prompts.Length > 0) ? this.Prompts[1].name : ""
            }
        } catch {
            this._CreateDefault()
        }
    }

    ; Save prompts to JSON file.
    static Save() {
        ; Build JSON string manually for zero-dependency operation
        json := '{`n  "active": ' . this._JsonString(this.ActivePrompt) . ',`n  "prompts": [`n'

        for i, p in this.Prompts {
            json .= '    {`n      "name": ' . this._JsonString(p.name) . ',`n'
            json .= '      "content": ' . this._JsonString(p.content) . '`n    }'
            if i < this.Prompts.Length
                json .= ','
            json .= '`n'
        }

        json .= '  ]`n}'

        ; Ensure configs directory exists
        cfgDir := A_ScriptDir "\configs"
        if !DirExist(cfgDir)
            DirCreate(cfgDir)

        try FileDelete(this.PromptsFile)
        FileAppend(json, this.PromptsFile, "UTF-8")
    }

    ; Add a new prompt. Returns true on success, false if name already exists.
    static Add(name, content) {
        if this.FindByName(name)
            return false

        this.Prompts.Push({ name: name, content: content })

        ; Auto-select if this is the first prompt
        if this.ActivePrompt == ""
            this.ActivePrompt := name

        this.Save()
        return true
    }

    ; Update an existing prompt by index (1-based).
    static Update(index, name, content) {
        if index < 1 || index > this.Prompts.Length
            return false

        ; Check for duplicate name (excluding self)
        existing := this.FindByName(name)
        if existing && existing != index
            return false

        oldName := this.Prompts[index].name
        this.Prompts[index].name := name
        this.Prompts[index].content := content

        ; Update active prompt reference if name changed
        if this.ActivePrompt == oldName
            this.ActivePrompt := name

        this.Save()
        return true
    }

    ; Delete a prompt by index (1-based).
    static Delete(index) {
        if index < 1 || index > this.Prompts.Length
            return false

        deletedName := this.Prompts[index].name
        this.Prompts.RemoveAt(index)

        ; Clear active if it was deleted, or set to first available
        if this.ActivePrompt == deletedName {
            this.ActivePrompt := (this.Prompts.Length > 0) ? this.Prompts[1].name : ""
        }

        this.Save()
        return true
    }

    ; Set the active prompt by name.
    static SetActive(name) {
        if this.FindByName(name) {
            this.ActivePrompt := name
            this.Save()
            return true
        }
        return false
    }

    ; Get the content of the currently active prompt, or empty string if none.
    static GetActiveContent() {
        if this.ActivePrompt == ""
            return ""

        idx := this.FindByName(this.ActivePrompt)
        if idx
            return this.Prompts[idx].content

        return ""
    }

    ; Find a prompt by name. Returns its index (1-based) or 0 if not found.
    static FindByName(name) {
        for i, p in this.Prompts {
            if p.name == name
                return i
        }
        return 0
    }

    ; Check if any prompts are configured.
    static HasPrompts() {
        return this.Prompts.Length > 0
    }

    ; --- Private helpers ---

    ; Create a default prompts file with example prompts.
    static _CreateDefault() {
        this.Prompts := [
            {
                name: "Translate to Chinese",
                content: "Please translate the following text to Simplified Chinese. Only output the translated text without any explanations or notes."
            },
            {
                name: "Summarize",
                content: "Please summarize the following text concisely. Focus on the key points and main ideas."
            }
        ]
        this.ActivePrompt := "Translate to Chinese"
        this.Save()
    }

    ; Minimal JSON string escaper.
    static _JsonString(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        ; Strip control characters that would break JSON
        str := RegExReplace(str, "[\x00-\x08\x0B\x0C\x0E-\x1F]", "")
        return '"' . str . '"'
    }

    ; Minimal JSON parser for our simple format.
    ; Returns a Map with "active" and "prompts" keys.
    static _ParseJson(raw) {
        result := Map("active", "", "prompts", [])

        ; Extract "active" field
        if RegExMatch(raw, '"active"\s*:\s*"([^"]*)"', &m)
            result["active"] := m[1]

        ; Extract each prompt object
        ; Find all {...} blocks inside the "prompts" array
        pos := InStr(raw, '"prompts"')
        if !pos
            return result

        ; Find the opening bracket of the prompts array
        bracketPos := InStr(raw, '[', , pos)
        if !bracketPos
            return result

        ; Extract individual objects by tracking brace depth
        depth := 0
        objStart := 0
        i := bracketPos + 1

        while i <= StrLen(raw) {
            ch := SubStr(raw, i, 1)

            if ch == '{' {
                if depth == 0
                    objStart := i
                depth++
            } else if ch == '}' {
                depth--
                if depth == 0 && objStart > 0 {
                    objStr := SubStr(raw, objStart, i - objStart + 1)
                    parsed := this._ParseSinglePrompt(objStr)
                    if parsed
                        result["prompts"].Push(parsed)
                    objStart := 0
                }
            }

            i++
        }

        return result
    }

    ; Parse a single {"name":"...","content":"..."} object.
    static _ParseSinglePrompt(objStr) {
        name := ""
        content := ""

        if RegExMatch(objStr, '"name"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
            name := this._UnescapeJson(m[1])

        if RegExMatch(objStr, '"content"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
            content := this._UnescapeJson(m[1])

        if name == ""
            return ""

        return { name: name, content: content }
    }

    ; Unescape JSON string escapes.
    static _UnescapeJson(str) {
        str := StrReplace(str, "\n", "`n")
        str := StrReplace(str, "\r", "`r")
        str := StrReplace(str, "\t", "`t")
        str := StrReplace(str, '\"', '"')
        str := StrReplace(str, "\\", "\")
        str := RegExReplace(str, "\\u([0-9A-Fa-f]{4})", (m) => Chr(Integer("0x" . m[1])))
        return str
    }
}
