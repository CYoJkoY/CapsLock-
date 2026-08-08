#Requires AutoHotkey v2.0

; Manages AI prompts using .prompt files. Each prompt's name is the filename
; (without extension), and its content is the file content.
; The active prompt name is stored in Config.ini under [AI] section as "ActivePrompt".
class PromptManager {
    static PromptsDir := A_ScriptDir "\configs\prompts"
    static Prompts := []          ; Array of {name, content}
    static ActivePrompt := ""     ; Name of the currently active prompt
    static EXT := ".prompt"       ; Unique extension for prompt files

    ; ------------------------------------------------------------------------
    ; Load prompts from the filesystem. Creates defaults if the directory
    ; is empty. Active prompt is read from Config.ini.
    ; ------------------------------------------------------------------------
    static Load() {
        this._EnsureDir()

        ; --- Load active prompt from Config.ini ---
        this.ActivePrompt := ""
        try {
            this.ActivePrompt := IniRead(AppState.ConfigFile, "AI", "ActivePrompt", "")
        } catch {
            this.ActivePrompt := ""
        }

        ; --- Scan .prompt files ---
        this.Prompts := []
        Loop Files, this.PromptsDir "\*" this.EXT, "F" {
            filename := A_LoopFileName
            if (filename == "_active" this.EXT)   ; skip if someone accidentally left it
                continue
            name := SubStr(filename, 1, -StrLen(this.EXT))   ; strip extension
            try {
                content := FileRead(A_LoopFileFullPath, "UTF-8")
                this.Prompts.Push({ name: name, content: content })
            } catch {
                ; Skip unreadable files
            }
        }

        ; --- Validate active prompt ---
        if this.ActivePrompt != "" && !this.FindByName(this.ActivePrompt) {
            this.ActivePrompt := (this.Prompts.Length > 0) ? this.Prompts[1].name : ""
        }

        ; --- Create defaults if empty ---
        if this.Prompts.Length == 0 {
            this._CreateDefault()
        }

        ; Ensure active is saved (e.g., after fallback or defaults)
        this._SaveActive()
    }

    ; ------------------------------------------------------------------------
    ; Save the active prompt state to Config.ini.
    ; ------------------------------------------------------------------------
    static Save() {
        this._SaveActive()
    }

    ; ------------------------------------------------------------------------
    ; Add a new prompt. Returns true on success, false if name already exists.
    ; Writes the prompt to a new .prompt file immediately.
    ; ------------------------------------------------------------------------
    static Add(name, content) {
        if this.FindByName(name)
            return false

        this._EnsureDir()

        safeName := this._SanitizeFilename(name)
        if safeName == ""
            safeName := "prompt"

        filePath := this.PromptsDir "\" safeName this.EXT

        ; Ensure file does not already exist (defensive)
        if FileExist(filePath) {
            ; Append a timestamp to avoid collision
            safeName .= "_" . A_TickCount
            filePath := this.PromptsDir "\" safeName this.EXT
        }

        FileAppend(content, filePath, "UTF-8")
        this.Prompts.Push({ name: name, content: content })

        ; Auto-select if this is the first prompt
        if this.ActivePrompt == ""
            this.ActivePrompt := name

        this._SaveActive()
        return true
    }

    ; ------------------------------------------------------------------------
    ; Update an existing prompt by index (1-based). Returns true on success.
    ; If the name changes, the file is renamed accordingly.
    ; ------------------------------------------------------------------------
    static Update(index, name, content) {
        if index < 1 || index > this.Prompts.Length
            return false

        ; Check for duplicate name (excluding self)
        existing := this.FindByName(name)
        if existing && existing != index
            return false

        oldName := this.Prompts[index].name
        oldSafe := this._SanitizeFilename(oldName)
        newSafe := this._SanitizeFilename(name)
        if newSafe == ""
            newSafe := "prompt"

        oldPath := this.PromptsDir "\" oldSafe this.EXT
        newPath := this.PromptsDir "\" newSafe this.EXT

        ; If name changed, rename the file
        if oldName != name {
            try {
                if FileExist(newPath)
                    FileDelete(newPath)
                FileMove(oldPath, newPath, 1)
            } catch {
                return false
            }
        }

        ; Write new content (overwrite existing file)
        try {
            FileDelete(oldPath)   ; if name didn't change, overwrite
            FileAppend(content, newPath, "UTF-8")
        } catch {
            return false
        }

        this.Prompts[index].name := name
        this.Prompts[index].content := content

        ; Update active reference if name changed
        if this.ActivePrompt == oldName
            this.ActivePrompt := name

        this._SaveActive()
        return true
    }

    ; ------------------------------------------------------------------------
    ; Delete a prompt by index (1-based). Returns true on success.
    ; ------------------------------------------------------------------------
    static Delete(index) {
        if index < 1 || index > this.Prompts.Length
            return false

        deletedName := this.Prompts[index].name
        safeName := this._SanitizeFilename(deletedName)
        filePath := this.PromptsDir "\" safeName this.EXT
        try FileDelete(filePath)

        this.Prompts.RemoveAt(index)

        ; Clear active if it was deleted, or set to first available
        if this.ActivePrompt == deletedName {
            this.ActivePrompt := (this.Prompts.Length > 0) ? this.Prompts[1].name : ""
        }

        this._SaveActive()
        return true
    }

    ; ------------------------------------------------------------------------
    ; Set the active prompt by name. Returns true on success.
    ; ------------------------------------------------------------------------
    static SetActive(name) {
        if this.FindByName(name) {
            this.ActivePrompt := name
            this._SaveActive()
            return true
        }
        return false
    }

    ; ------------------------------------------------------------------------
    ; Get the content of the currently active prompt, or empty string if none.
    ; ------------------------------------------------------------------------
    static GetActiveContent() {
        if this.ActivePrompt == ""
            return ""
        idx := this.FindByName(this.ActivePrompt)
        if idx
            return this.Prompts[idx].content
        return ""
    }

    ; ------------------------------------------------------------------------
    ; Find a prompt by name. Returns its index (1-based) or 0 if not found.
    ; ------------------------------------------------------------------------
    static FindByName(name) {
        for i, p in this.Prompts {
            if p.name == name
                return i
        }
        return 0
    }

    ; ------------------------------------------------------------------------
    ; Check if any prompts are configured.
    ; ------------------------------------------------------------------------
    static HasPrompts() {
        return this.Prompts.Length > 0
    }

    ; ------------------------------------------------------------------------
    ; --- Private helpers ---
    ; ------------------------------------------------------------------------

    ; Ensure the prompts directory exists.
    static _EnsureDir() {
        if !DirExist(this.PromptsDir)
            DirCreate(this.PromptsDir)
    }

    ; Create default prompts when no prompts exist.
    static _CreateDefault() {
        this._EnsureDir()
        defaults := [
            {
                name: "Translate to Chinese",
                content: "Please translate the following text to Simplified Chinese. Only output the translated text without any explanations or notes."
            },
            {
                name: "Summarize",
                content: "Please summarize the following text concisely. Focus on the key points and main ideas."
            }
        ]
        this.Prompts := []
        for d in defaults {
            this.Add(d.name, d.content)
        }
        this.ActivePrompt := defaults[1].name
        this._SaveActive()
    }

    ; Save the active prompt name to Config.ini (section "AI", key "ActivePrompt").
    static _SaveActive() {
        if this.ActivePrompt != "" {
            try IniWrite(this.ActivePrompt, AppState.ConfigFile, "AI", "ActivePrompt")
        } else {
            ; Write empty to clear the key if needed
            try IniWrite("", AppState.ConfigFile, "AI", "ActivePrompt")
        }
    }

    ; Sanitize a string for use as a Windows filename.
    ; Replaces invalid characters with underscores.
    static _SanitizeFilename(name) {
        ; Invalid Windows filename characters: \ / : * ? " < > |
        invalid := ["\", "/", ":", "*", "?", "`"`"", "<", ">", "|"]
        for ch in invalid
            name := StrReplace(name, ch, "_")
        ; Replace newlines and tabs with spaces
        name := StrReplace(name, "`n", " ")
        name := StrReplace(name, "`r", " ")
        name := StrReplace(name, "`t", " ")
        ; Collapse multiple spaces
        name := RegExReplace(name, " +", " ")
        name := Trim(name)
        ; If result is empty, use a fallback
        if name == ""
            name := "prompt"
        ; Remove leading/trailing dots and spaces (reserved)
        name := RegExReplace(name, "^[. ]+", "")
        name := RegExReplace(name, "[. ]+$", "")
        if name == ""
            name := "prompt"
        return name
    }
}
